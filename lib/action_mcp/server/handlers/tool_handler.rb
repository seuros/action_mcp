# frozen_string_literal: true

module ActionMCP
  module Server
    module Handlers
      module ToolHandler
        include ErrorAware

        def process_tools(rpc_method, id, params)
          params ||= {}

          with_error_handling(id) do
            handler = tool_method_handlers[rpc_method]
            if handler
              send(handler, id, params)
            else
              Rails.logger.warn("Unknown tools method: #{rpc_method}")
              raise JSON_RPC::JsonRpcError.new(:method_not_found, message: "Unknown tools method: #{rpc_method}")
            end
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
          _meta = params["_meta"] || params[:_meta] || {}
          transport.send_tools_call(id, name, arguments, _meta)
        end

        def extract_arguments(params)
          params["arguments"] || params[:arguments] || {}
        end
      end
    end
  end
end
