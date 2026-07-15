# frozen_string_literal: true

module ActionMCP
  # ActiveJob for executing tools asynchronously in task-augmented mode
  # Part of MCP 2025-11-25 Tasks specification with ActiveJob::Continuable support
  class ToolExecutionJob < ActiveJob::Base
    include ActiveJob::Continuable

    queue_as :mcp_tasks

    # Retry configuration for transient failures
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    # Ensure tasks reach terminal state on permanent failure
    discard_on StandardError do |job, error|
      handle_job_discard(job, error)
    end

    # @param task_id [String] Task ID
    # @param tool_name [String] Name of the tool to execute
    # @param arguments [Hash] Tool arguments
    # @param meta [Hash] Request metadata
    def perform(task_id, tool_name, arguments, meta = {})
      @task = step(:load_task, task_id)
      return if @task.nil? || @task.terminal?

      @session = step(:validate_session, @task)
      return unless @session

      @tool = step(:prepare_tool, @session, tool_name, arguments, @task)
      return unless @tool

      step(:execute_tool) do
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

    def execute_with_reloader(tool, session)
      if Rails.env.development?
        # Preserve Current attributes across reloader boundary
        current_user = ActionMCP::Current.user
        current_gateway = ActionMCP::Current.gateway

        Rails.application.reloader.wrap do
          ActionMCP::Current.user = current_user
          ActionMCP::Current.gateway = current_gateway
          tool.call
        end
      else
        tool.call
      end
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

    def self.handle_job_discard(job, error)
      task_id = job.arguments.first
      task = Session::Task.find_by(id: task_id)
      return unless task&.persisted?

      Rails.logger.error "[ToolExecutionJob] Discarding job for task #{task_id}: #{error.class} - #{error.message}"
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
    end
  end
end
