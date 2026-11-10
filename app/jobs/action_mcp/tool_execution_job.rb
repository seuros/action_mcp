# frozen_string_literal: true

module ActionMCP
  # ActiveJob for executing tools asynchronously in task-augmented mode
  # Part of MCP 2025-11-25 Tasks specification with ActiveJob::Continuable support
  class ToolExecutionJob < ActiveJob::Base
    include ActiveJob::Continuable

    queue_as :mcp_tasks

    # The gateway resolves identities per request into ActionMCP::Current; they
    # travel with the job so perform and schema procs see the same current_user
    # as a synchronous call. Values ActiveJob cannot serialize stay behind.
    CARRIED_CURRENT_ATTRIBUTES = %i[user session_data].freeze

    attr_reader :current_attributes

    before_enqueue { @current_attributes ||= self.class.capture_current }
    around_perform { |job, block| ActionMCP::Current.set(job.current_attributes.to_h) { block.call } }

    # A failure marks the task failed, so clients polling tasks/get see a
    # terminal state, then re-raises so the job fails visibly in the queue
    # backend. A manual retry of such a job finds the task terminal and stops.
    rescue_from StandardError do |error|
      self.class.fail_task_for(self, error)
      raise error
    end

    # Declared last, so checked first: transient infrastructure errors retry.
    retry_on ActiveRecord::Deadlocked, ActiveRecord::ConnectionNotEstablished, ActiveRecord::LockWaitTimeout,
             wait: :polynomially_longer, attempts: 3 do |job, error|
      fail_task_for(job, error)
      raise error
    end

    def self.capture_current
      CARRIED_CURRENT_ATTRIBUTES.each_with_object({}) do |name, carried|
        value = ActionMCP::Current.public_send(name)
        next if value.blank?

        ActiveJob::Arguments.serialize([ value ])
        carried[name] = value
      rescue ActiveJob::SerializationError
        Rails.logger.warn "[ToolExecutionJob] ActionMCP::Current.#{name} (#{value.class}) " \
                          "cannot be serialized for ActiveJob; the task runs without it"
      end
    end

    def serialize
      super.merge("action_mcp_current" => ActiveJob::Arguments.serialize([ current_attributes.to_h ]))
    end

    def deserialize(job_data)
      super
      @current_attributes = ActiveJob::Arguments.deserialize(job_data.fetch("action_mcp_current", [ {} ])).first
    end

    # @param task_id [String] Task ID
    # @param tool_name [String] Name of the tool to execute
    # @param arguments [Hash] Tool arguments
    # @param meta [Hash] Request metadata
    def perform(task_id, tool_name, arguments, meta = {})
      # Loading reruns on every resumption; only the tool run is a checkpointed
      # step, so a resumed job never executes the tool twice.
      @task = load_task(task_id)
      return if @task.nil? || @task.terminal?

      @session = validate_session(@task)
      return unless @session

      @tool = prepare_tool(@session, tool_name, arguments, @task)
      return unless @tool

      step :execute_tool do
        result = execute_with_reloader(@tool, @session)
        update_task_result(@task, result)
      end
    end

    private

    def load_task(task_id)
      task = Session::Task.find_by(id: task_id)
      unless task
        Rails.logger.error "[ToolExecutionJob] Task not found: #{task_id}"
        return nil
      end

      task.with_lock do
        task.record_step!(:job_started) unless task.terminal?
      end
      task
    end

    def validate_session(task)
      session = task.session
      unless session
        fail_task(
          task,
          status_message: "Session not found",
          result_payload: { code: -32_603, message: "Session not found" }
        )
        return nil
      end

      session
    end

    def prepare_tool(session, tool_name, arguments, task)
      tool_class = session.registered_tools.find { |t| t.tool_name == tool_name }
      unless tool_class
        fail_task(
          task,
          status_message: "Tool '#{tool_name}' not found",
          result_payload: {
            code: -32_601,
            message: "Tool '#{tool_name}' not found"
          }
        )
        return nil
      end

      # Create and configure tool instance
      tool = tool_class.from_wire(arguments)
      tool.with_context({
        session: session,
        request: {
          params: @task.request_params
        }
      })
      # Enable report_progress! inside the tool during task-augmented runs
      tool.instance_variable_set(:@_task, task)

      tool
    rescue ArgumentError, ActiveModel::UnknownAttributeError => e
      fail_task(
        task,
        status_message: "Invalid tool input",
        result_payload: Server::ToolResult.execution_error(e.message).to_h
      )
      nil
    end

    def fail_task(task, status_message:, result_payload:)
      task.with_lock do
        return false if task.terminal?

        task.status_message = status_message
        task.result_payload = result_payload
        task.mark_failed!
      end

      true
    end

    def execute_with_reloader(tool, _session)
      DevReloader.wrap { tool.call }
    end

    def update_task_result(task, result)
      result = Server::ToolResult.normalize(result)
      payload = result.to_h

      task.with_lock do
        return if task.terminal?

        if result.is_error || payload[:isError] || payload["isError"]
          task.result_payload = payload
          task.status_message = result.respond_to?(:error_message) ? result.error_message : "Tool returned error"
          task.mark_failed!
        else
          task.result_payload = payload
          task.record_step!(:completed)
          task.complete!
        end
      end
    end

    def self.fail_task_for(job, error)
      task_id = job.arguments.first
      task = Session::Task.find_by(id: task_id)
      return unless task&.persisted?

      Rails.logger.error "[ToolExecutionJob] Task #{task_id} failed: #{error.class} - #{error.message}"
      Rails.logger.error error.backtrace&.first(10)&.join("\n")

      task.with_lock do
        return if task.terminal?

        task.update!(
          status_message: "Job failed: #{error.message}",
          result_payload: {
            code: -32_603,
            message: "Job failed: #{error.message}"
          },
          continuation_state: {
            step: :failed,
            error: { class: error.class.name, message: error.message },
            timestamp: Time.current.iso8601
          }
        )
        task.mark_failed!
      end
    rescue StandardError => e
      # The original error still propagates; this one is reported alongside it.
      Rails.error.report(e, handled: true, severity: :error, context: { task_id: task_id })
    end
  end
end
