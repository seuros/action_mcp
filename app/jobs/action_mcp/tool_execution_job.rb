# frozen_string_literal: true

module ActionMCP
  # ActiveJob for executing tools asynchronously in task-augmented mode
  # Part of MCP 2025-11-25 Tasks specification
  class ToolExecutionJob < ActiveJob::Base
    queue_as :mcp_tasks

    # Retry configuration for transient failures
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    # @param task_id [String] Task ID
    # @param tool_name [String] Name of the tool to execute
    # @param arguments [Hash] Tool arguments
    # @param meta [Hash] Request metadata
    def perform(task_id, tool_name, arguments, meta = {})
      task = Session::Task.find_by(id: task_id)
      unless task
        Rails.logger.error "[ToolExecutionJob] Task not found: #{task_id}"
        return
      end

      # Skip if task was cancelled or already terminal
      if task.terminal?
        Rails.logger.info "[ToolExecutionJob] Task #{task_id} is already in terminal state: #{task.status}"
        return
      end

      session = task.session
      unless session
        Rails.logger.error "[ToolExecutionJob] Session not found for task: #{task_id}"
        task.update(status_message: "Session not found")
        task.mark_failed!
        return
      end

      execute_tool(task, session, tool_name, arguments, meta)
    rescue StandardError => e
      handle_execution_error(task, e)
      raise # Re-raise for retry logic
    end

    private

    def execute_tool(task, session, tool_name, arguments, meta)
      # Find tool in session's registry
      tool_class = session.registered_tools.find { |t| t.tool_name == tool_name }
      unless tool_class
        task.update(status_message: "Tool '#{tool_name}' not found")
        task.mark_failed!
        return
      end

      # Create and configure tool instance
      tool = tool_class.new(arguments)
      tool.with_context({
        session: session,
        request: {
          params: task.request_params
        }
      })

      # Execute tool
      result = execute_with_reloader(tool, session)

      # Update task with result
      update_task_result(task, result)
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
      if result.is_error
        task.result_payload = result.to_h
        task.status_message = result.respond_to?(:error_message) ? result.error_message : "Tool returned error"
        task.mark_failed!
      else
        task.result_payload = result.to_h
        task.complete!
      end
    end

    def handle_execution_error(task, error)
      return unless task&.persisted?
      return if task.terminal?

      Rails.logger.error "[ToolExecutionJob] Error executing task #{task.id}: #{error.class} - #{error.message}"
      Rails.logger.error error.backtrace&.first(10)&.join("\n")

      task.update(status_message: "#{error.class}: #{error.message}")
      # Don't mark failed yet - retry logic may handle it
    end
  end
end
