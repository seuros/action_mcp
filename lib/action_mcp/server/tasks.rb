# frozen_string_literal: true

module ActionMCP
  module Server
    # Tasks module for MCP 2025-11-25 specification
    # Provides methods for handling task-related requests:
    # - tasks/get: Get task status and data
    # - tasks/result: Get task result (blocking until a terminal state)
    # - tasks/list: List tasks for the session
    # - tasks/cancel: Cancel a task
    module Tasks
      # Get task status and metadata
      # @param request_id [String, Integer] JSON-RPC request ID
      # @param task_id [String] Task ID to retrieve
      def send_tasks_get(request_id, task_id)
        task = find_task(task_id)
        return unless task

        send_jsonrpc_response(request_id, result: task.to_task_data)
      end

      # Get task result, blocking until the task reaches a terminal state.
      # @param request_id [String, Integer] JSON-RPC request ID
      # @param task_id [String] Task ID to get result for
      def send_tasks_result(request_id, task_id)
        task = find_task(task_id)
        return unless task

        task = wait_for_terminal_task(task_id) unless task.terminal?
        unless task
          send_jsonrpc_error(request_id, :invalid_params, "Task '#{task_id}' not found")
          return
        end

        if (error = task.to_task_error)
          send_jsonrpc_response(request_id, error: error)
        else
          send_jsonrpc_response(request_id, result: task.to_task_result)
        end
      rescue ActiveRecord::RecordNotFound
        send_jsonrpc_error(request_id, :invalid_params, "Task '#{task_id}' not found")
      end

      # List tasks for the session with keyset pagination.
      # Tasks always paginate (AR-backed, can grow unbounded).
      # Cursor is the last task id from the previous page. We resolve it
      # through AR so the boundary matches the recent scope exactly.
      # @param request_id [String, Integer] JSON-RPC request ID
      # @param cursor [String, nil] Pagination cursor
      def send_tasks_list(request_id, cursor: nil)
        page, next_cursor = paginate_tasks_by_recent(cursor: cursor, page_size: pagination_page_size || 50)

        result = { tasks: page.map(&:to_task_data) }
        result[:nextCursor] = next_cursor if next_cursor

        send_jsonrpc_response(request_id, result: result)
      rescue Server::CursorError => e
        send_jsonrpc_error(request_id, :invalid_params, e.message)
      end

      # Cancel a task
      # @param request_id [String, Integer] JSON-RPC request ID
      # @param task_id [String] Task ID to cancel
      def send_tasks_cancel(request_id, task_id)
        task = find_task(task_id)
        return unless task

        terminal_status = nil
        task.with_lock do
          if task.terminal?
            terminal_status = task.status
            next
          end

          task.status_message = "The task was cancelled by request." if task.status_message.blank?
          task.result_payload ||= {
            code: -32_000,
            message: "Task was cancelled"
          }
          task.save! if task.changed?
          task.cancel!
        end

        if terminal_status
          send_jsonrpc_error(request_id, :invalid_params,
                             "Cannot cancel task in terminal status: #{terminal_status}")
          return
        end

        send_jsonrpc_response(request_id, result: task.to_task_data)
      end

      # Send task status notification
      # @param task [ActionMCP::Session::Task] Task to notify about
      def send_task_status_notification(task)
        send_jsonrpc_notification(
          JsonRpcHandlerBase::Methods::NOTIFICATIONS_TASKS_STATUS,
          task.to_task_data
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

      def paginate_tasks_by_recent(cursor:, page_size:)
        relation = session.tasks.recent

        if cursor
          cursor_task = find_task_cursor(cursor)
          relation = relation.before_recent(cursor_task)
        end

        page = relation.limit(page_size + 1).to_a
        has_more = page.size > page_size
        items = has_more ? page.first(page_size) : page
        next_cursor = has_more ? encode_keyset_cursor(items.last, :id) : nil

        [ items, next_cursor ]
      end

      def find_task_cursor(cursor)
        task_id = decode_keyset_cursor(cursor)
        task = session.tasks.select(:id, :created_at).find_by(id: task_id)
        raise Server::CursorError, "Invalid cursor" unless task

        task
      end

      def wait_for_terminal_task(task_id)
        loop do
          task = load_task_for_result(task_id)
          return task if task.nil? || task.terminal?

          sleep ActionMCP.configuration.tasks_result_poll_interval.to_f
        end
      end

      def load_task_for_result(task_id)
        ActiveRecord::Base.connection_pool.with_connection do
          session.tasks.find_by(id: task_id)
        end
      end
    end
  end
end
