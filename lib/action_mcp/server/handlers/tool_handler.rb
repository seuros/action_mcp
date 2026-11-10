# frozen_string_literal: true

module ActionMCP
  module Server
    module Handlers
      module ToolHandler
        include ErrorAware
        include Dispatching

        def process_tools(rpc_method, id, params)
          params ||= {}

          with_error_handling(id) do
            require_params_object!(params, "Tool")

            dispatch_rpc(tool_method_handlers, "tools", rpc_method, id, params)
          end
        end

        private

        def tool_method_handlers
          {
            JsonRpcHandlerBase::Methods::TOOLS_LIST => :handle_tools_list,
            JsonRpcHandlerBase::Methods::TOOLS_CALL => :handle_tools_call
          }
        end

        def handle_tools_list(id, params)
          transport.send_tools_list(id, params)
        end

        def handle_tools_call(id, params)
          name = validate_required_param(params, "name", "Tool name is required")
          arguments = extract_arguments(params)
          unless arguments.is_a?(Hash)
            raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "Tool arguments must be an object")
          end

          _meta = params["_meta"] || params[:_meta] || {}
          task_params = params.key?("task") ? params["task"] : params[:task]
          transport.send_tools_call(id, name, arguments, _meta, task_params)
        end

        def extract_arguments(params)
          params["arguments"] || params[:arguments] || {}
        end
      end
    end
  end
end
