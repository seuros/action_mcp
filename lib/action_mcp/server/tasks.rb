# frozen_string_literal: true

module ActionMCP
  module Server
    # Tasks module for MCP 2025-11-25 specification
    # Provides methods for handling task-related requests:
    # - tasks/get: Get task status and data
    # - tasks/result: Get task result (blocking until terminal state)
    # - tasks/list: List tasks for the session
    # - tasks/cancel: Cancel a task
    module Tasks
      # Get task status and metadata
      # @param request_id [String, Integer] JSON-RPC request ID
      # @param task_id [String] Task ID to retrieve
      def send_tasks_get(request_id, task_id)
        task = find_task(task_id)
        return unless task

        send_jsonrpc_response(request_id, result: { task: task.to_task_data })
      end

      # Get task result, blocking until task reaches terminal state
      # @param request_id [String, Integer] JSON-RPC request ID
      # @param task_id [String] Task ID to get result for
      def send_tasks_result(request_id, task_id)
        task = find_task(task_id)
        return unless task

        # If task is not in terminal state, wait for it
        # In async execution, client should poll or use SSE for notifications
        unless task.terminal?
          send_jsonrpc_error(request_id, :invalid_request,
                             "Task is not yet complete. Current status: #{task.status}")
          return
        end

        send_jsonrpc_response(request_id, result: task.to_task_result)
      end

      # List tasks for the session with optional pagination
      # @param request_id [String, Integer] JSON-RPC request ID
      # @param cursor [String, nil] Pagination cursor
      def send_tasks_list(request_id, cursor: nil)
        # Parse cursor if provided
        offset = cursor.to_i if cursor.present?
        offset ||= 0
        limit = 50

        tasks = session.tasks.recent.offset(offset).limit(limit + 1)
        has_more = tasks.length > limit
        tasks = tasks.first(limit)

        result = {
          tasks: tasks.map(&:to_task_data)
        }
        result[:nextCursor] = (offset + limit).to_s if has_more

        send_jsonrpc_response(request_id, result: result)
      end

      # Cancel a task
      # @param request_id [String, Integer] JSON-RPC request ID
      # @param task_id [String] Task ID to cancel
      def send_tasks_cancel(request_id, task_id)
        task = find_task(task_id)
        return unless task

        if task.terminal?
          send_jsonrpc_error(request_id, :invalid_params,
                             "Cannot cancel task in terminal status: #{task.status}")
          return
        end

        task.cancel!
        send_jsonrpc_response(request_id, result: { task: task.to_task_data })
      end

      # Resume a task from input_required state
      # @param request_id [String, Integer] JSON-RPC request ID
      # @param task_id [String] Task ID to resume
      # @param input [Object] Input data for the task
      def send_tasks_resume(request_id, task_id, input)
        task = find_task(task_id)
        return unless task

        unless task.input_required?
          send_jsonrpc_error(request_id, :invalid_params,
                             "Task is not awaiting input. Current status: #{task.status}")
          return
        end

        # Store input in continuation state
        continuation = task.continuation_state || {}
        continuation[:input] = input
        task.update!(continuation_state: continuation)

        # Resume task and re-enqueue job
        task.resume_from_continuation!

        send_jsonrpc_response(request_id, result: { task: task.to_task_data })
      end

      # Send task status notification
      # @param task [ActionMCP::Session::Task] Task to notify about
      def send_task_status_notification(task)
        send_jsonrpc_notification(
          JsonRpcHandlerBase::Methods::NOTIFICATIONS_TASKS_STATUS,
          { task: task.to_task_data }
        )
      end

      private

      def find_task(task_id)
        task = session.tasks.find_by(id: task_id)
        unless task
          Rails.logger.warn "Task not found: #{task_id}"
          # Note: we need the request_id to send error, but this is called from handler
          # The handler should handle the nil return
        end
        task
      end
    end
  end
end
