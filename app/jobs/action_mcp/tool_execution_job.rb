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

      @tool = step(:prepare_tool, @session, tool_name, arguments)
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

      task.record_step!(:job_started)
      task
    end

    def validate_session(task)
      session = task.session
      unless session
        task.update(status_message: "Session not found")
        task.mark_failed!
        return nil
      end

      session
    end

    def prepare_tool(session, tool_name, arguments)
      tool_class = session.registered_tools.find { |t| t.tool_name == tool_name }
      unless tool_class
        @task.update(status_message: "Tool '#{tool_name}' not found")
        @task.mark_failed!
        return nil
      end

      # Create and configure tool instance
      tool = tool_class.new(arguments)
      tool.with_context({
        session: session,
        request: {
          params: @task.request_params
        }
      })

      tool
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
      return if task.terminal? # Guard against double-complete

      if result.is_error
        task.result_payload = result.to_h
        task.status_message = result.respond_to?(:error_message) ? result.error_message : "Tool returned error"
        task.mark_failed!
      else
        task.result_payload = result.to_h
        task.record_step!(:completed)
        task.complete!
      end
    end

    def self.handle_job_discard(job, error)
      task_id = job.arguments.first
      task = Session::Task.find_by(id: task_id)
      return unless task&.persisted?
      return if task.terminal?

      Rails.logger.error "[ToolExecutionJob] Discarding job for task #{task_id}: #{error.class} - #{error.message}"
      Rails.logger.error error.backtrace&.first(10)&.join("\n")

      task.update(
        status_message: "Job failed: #{error.message}",
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
