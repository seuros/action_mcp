# frozen_string_literal: true

module ActionMCP
  module Server
    module Handlers
      module ResourceHandler
        include ErrorAware

        def process_resources(rpc_method, id, params)
          params ||= {}

          with_error_handling(id) do
            handler = resource_method_handlers[rpc_method]
            if handler
              send(handler, id, params)
            else
              Rails.logger.warn("Unknown resources method: #{rpc_method}")
              raise JSON_RPC::JsonRpcError.new(:method_not_found, message: "Unknown resources method: #{rpc_method}")
            end
          end
        end

        private

        def resource_method_handlers
          {
            JsonRpcHandlerBase::Methods::RESOURCES_LIST => :handle_resources_list,
            JsonRpcHandlerBase::Methods::RESOURCES_TEMPLATES_LIST => :handle_resources_templates_list,
            JsonRpcHandlerBase::Methods::RESOURCES_READ => :handle_resources_read,
            JsonRpcHandlerBase::Methods::RESOURCES_SUBSCRIBE => :handle_resources_subscribe,
            JsonRpcHandlerBase::Methods::RESOURCES_UNSUBSCRIBE => :handle_resources_unsubscribe
          }
        end

        def handle_resources_list(id, _params)
          message = transport.send_resources_list(id)
          extract_message_payload(message, id)
        end

        def handle_resources_templates_list(id, _params)
          message = transport.send_resource_templates_list(id)
          extract_message_payload(message, id)
        end

        def handle_resources_read(id, params)
          validate_params_present(params, "Resource URI is required")

          message = transport.send_resource_read(id, params)
          extract_message_payload(message, id)
        end

        def handle_resources_subscribe(id, params)
          uri = validate_required_param(params, "uri", "Resource URI is required")

          message = transport.send_resource_subscribe(id, uri)
          extract_message_payload(message, id)
        end

        def handle_resources_unsubscribe(id, params)
          uri = validate_required_param(params, "uri", "Resource URI is required")

          message = transport.send_resource_unsubscribe(id, uri)
          extract_message_payload(message, id)
        end
      end
    end
  end
end
