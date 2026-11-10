# frozen_string_literal: true

module ActionMCP
  module Server
    module Handlers
      module PromptHandler
        include ErrorAware
        include Dispatching

        def process_prompts(rpc_method, id, params)
          params ||= {}

          with_error_handling(id) do
            require_params_object!(params, "Prompt")

            dispatch_rpc(prompt_method_handlers, "prompts", rpc_method, id, params)
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
          name = validate_required_param(params, "name", "Prompt name is required")
          arguments = extract_arguments(params)
          unless arguments.is_a?(Hash)
            raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "Prompt arguments must be an object")
          end
          unless arguments.values.all? { |value| value.is_a?(String) }
            raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "Prompt argument values must be strings")
          end

          _meta = params["_meta"] || params[:_meta] || {}
          transport.send_prompts_get(id, name, arguments, _meta)
        end

        def handle_prompts_list(id, params)
          transport.send_prompts_list(id, params)
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
