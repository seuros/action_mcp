# frozen_string_literal: true

module ActionMCP
  module Server
    module Handlers
      # Handler for MCP 2025-11-25 Tasks feature
      # Tasks provide durable state machines for tracking async request execution
      module TaskHandler
        include ErrorAware

        def process_tasks(rpc_method, id, params)
          params ||= {}

          with_error_handling(id) do
            unless params.is_a?(Hash)
              raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "Task params must be an object")
            end

            unless transport.session.protocol_version == "2025-11-25"
              raise JSON_RPC::JsonRpcError.new(:method_not_found,
                                               message: "Tasks are only available in MCP 2025-11-25")
            end

            task_capabilities = negotiated_task_capabilities
            unless task_capabilities
              raise JSON_RPC::JsonRpcError.new(:method_not_found,
                                               message: "Tasks are not available for this session")
            end

            if rpc_method == JsonRpcHandlerBase::Methods::TASKS_LIST && !task_capabilities.key?(:list)
              raise JSON_RPC::JsonRpcError.new(:method_not_found,
                                               message: "Task listing is not available for this session")
            end

            if rpc_method == JsonRpcHandlerBase::Methods::TASKS_CANCEL && !task_capabilities.key?(:cancel)
              raise JSON_RPC::JsonRpcError.new(:method_not_found,
                                               message: "Task cancellation is not available for this session")
            end

            handler = task_method_handlers[rpc_method]
            if handler
              send(handler, id, params)
            else
              Rails.logger.warn("Unknown tasks method: #{rpc_method}")
              raise JSON_RPC::JsonRpcError.new(:method_not_found, message: "Unknown tasks method: #{rpc_method}")
            end
          end
        end

        private

        def task_method_handlers
          {
            JsonRpcHandlerBase::Methods::TASKS_GET => :handle_tasks_get,
            JsonRpcHandlerBase::Methods::TASKS_RESULT => :handle_tasks_result,
            JsonRpcHandlerBase::Methods::TASKS_LIST => :handle_tasks_list,
            JsonRpcHandlerBase::Methods::TASKS_CANCEL => :handle_tasks_cancel
          }
        end

        def negotiated_task_capabilities
          capabilities = (transport.session.server_capabilities || {}).with_indifferent_access
          task_capabilities = capabilities[:tasks]
          task_capabilities.with_indifferent_access if task_capabilities.is_a?(Hash)
        end

        def handle_tasks_get(id, params)
          task_id = validate_required_param(params, "taskId", "Task ID is required")
          task = find_task_or_error(id, task_id)
          return unless task

          transport.send_tasks_get(id, task_id)
        end

        def handle_tasks_result(id, params)
          task_id = validate_required_param(params, "taskId", "Task ID is required")
          task = find_task_or_error(id, task_id)
          return unless task

          transport.send_tasks_result(id, task_id)
        end

        def handle_tasks_list(id, params)
          cursor = params["cursor"]
          transport.send_tasks_list(id, cursor: cursor)
        end

        def handle_tasks_cancel(id, params)
          task_id = validate_required_param(params, "taskId", "Task ID is required")
          task = find_task_or_error(id, task_id)
          return unless task

          transport.send_tasks_cancel(id, task_id)
        end

        def find_task_or_error(id, task_id)
          task = transport.session.tasks.find_by(id: task_id)
          unless task
            transport.send_jsonrpc_error(id, :invalid_params, "Task '#{task_id}' not found")
            return nil
          end
          task
        end
      end
    end
  end
end
