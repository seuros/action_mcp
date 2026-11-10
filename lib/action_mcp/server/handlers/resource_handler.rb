# frozen_string_literal: true

require "uri"

module ActionMCP
  module Server
    module Handlers
      module ResourceHandler
        include ErrorAware
        include Dispatching

        def process_resources(rpc_method, id, params)
          params ||= {}

          with_error_handling(id) do
            require_params_object!(params, "Resource")

            capabilities = negotiated_capabilities(:resources)
            method_not_available!("Resources are not available for this session") unless capabilities

            if subscription_method?(rpc_method) && capabilities[:subscribe] != true
              method_not_available!("Resource subscriptions are not available for this session")
            end

            dispatch_rpc(resource_method_handlers, "resources", rpc_method, id, params)
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

        def subscription_method?(rpc_method)
          rpc_method == JsonRpcHandlerBase::Methods::RESOURCES_SUBSCRIBE ||
            rpc_method == JsonRpcHandlerBase::Methods::RESOURCES_UNSUBSCRIBE
        end

        def handle_resources_list(id, params)
          transport.send_resources_list(id, params)
        end

        def handle_resources_templates_list(id, params)
          transport.send_resource_templates_list(id, params)
        end

        def handle_resources_read(id, params)
          validate_resource_uri(params)
          transport.send_resource_read(id, params)
        end

        def handle_resources_subscribe(id, params)
          uri = validate_resource_uri(params)
          transport.send_resource_subscribe(id, uri)
        end

        def handle_resources_unsubscribe(id, params)
          uri = validate_resource_uri(params)
          transport.send_resource_unsubscribe(id, uri)
        end

        def validate_resource_uri(params)
          uri = validate_required_param(params, "uri", "Resource URI is required")
          parsed = URI.parse(uri) if uri.is_a?(String)
          return uri if parsed&.scheme.present?

          raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "Resource URI must be an absolute URI")
        rescue URI::InvalidURIError
          raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "Resource URI must be an absolute URI")
        end
      end
    end
  end
end
