# frozen_string_literal: true

module ActionMCP
  module Server
    module Handlers
      # Shared plumbing for the method-family handlers (prompts/, resources/, tools/, tasks/).
      module Dispatching
        private

        def require_params_object!(params, label)
          return if params.is_a?(Hash)

          raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "#{label} params must be an object")
        end

        def dispatch_rpc(handlers, family, rpc_method, id, params)
          handler = handlers[rpc_method]
          unless handler
            Rails.logger.warn("Unknown #{family} method: #{rpc_method}")
            raise JSON_RPC::JsonRpcError.new(:method_not_found, message: "Unknown #{family} method: #{rpc_method}")
          end

          send(handler, id, params)
        end

        def negotiated_capabilities(key)
          capabilities = (transport.session.server_capabilities || {}).with_indifferent_access
          value = capabilities[key]
          value.with_indifferent_access if value.is_a?(Hash)
        end

        def method_not_available!(message)
          raise JSON_RPC::JsonRpcError.new(:method_not_found, message: message)
        end
      end
    end
  end
end
