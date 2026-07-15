# frozen_string_literal: true

require "uri"

module ActionMCP
  module Server
    module Handlers
      module ResourceHandler
        include ErrorAware

        def process_resources(rpc_method, id, params)
          params ||= {}

          with_error_handling(id) do
            unless params.is_a?(Hash)
              raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "Resource params must be an object")
            end

            capabilities = negotiated_resource_capabilities
            unless capabilities
              raise JSON_RPC::JsonRpcError.new(:method_not_found,
                                               message: "Resources are not available for this session")
            end

            if subscription_method?(rpc_method) && capabilities[:subscribe] != true
              raise JSON_RPC::JsonRpcError.new(:method_not_found,
                                               message: "Resource subscriptions are not available for this session")
            end

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

        def negotiated_resource_capabilities
          capabilities = (transport.session.server_capabilities || {}).with_indifferent_access
          resource_capabilities = capabilities[:resources]
          resource_capabilities.with_indifferent_access if resource_capabilities.is_a?(Hash)
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
