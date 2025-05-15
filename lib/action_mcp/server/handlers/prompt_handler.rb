# frozen_string_literal: true

module ActionMCP
  module Server
    module Handlers
      module PromptHandler
        include ErrorAware

        def process_prompts(rpc_method, id, params)
          params ||= {}

          with_error_handling(id) do
            handler = prompt_method_handlers[rpc_method]
            if handler
              send(handler, id, params)
            else
              Rails.logger.warn("Unknown prompts method: #{rpc_method}")
              raise JSON_RPC::JsonRpcError.new(:method_not_found, message: "Unknown prompts method: #{rpc_method}")
            end
          end
        end

        private

        def prompt_method_handlers
          {
            JsonRpcHandlerBase::Methods::PROMPTS_GET => :handle_prompts_get,
            JsonRpcHandlerBase::Methods::PROMPTS_LIST => :handle_prompts_list
          }
        end

        def handle_prompts_get(id, params)
          name = extract_name(params)
          arguments = extract_arguments(params)

          message = transport.send_prompts_get(id, name, arguments)
          extract_message_payload(message, id)
        end

        def handle_prompts_list(id, _params)
          message = transport.send_prompts_list(id)
          extract_message_payload(message, id)
        end

        def extract_name(params)
          params["name"] || params[:name]
        end

        def extract_arguments(params)
          params["arguments"] || params[:arguments] || {}
        end
      end
    end
  end
end
