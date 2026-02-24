# frozen_string_literal: true

module ActionMCP
  module Server
    module Handlers
      module CustomMethodRouting
        private

        def route_custom_method_or_raise(rpc_method, id, params, transport)
          handler = ActionMCP.configuration.custom_method_handler
          return if handler&.call(rpc_method, id, params, transport)

          raise JSON_RPC::JsonRpcError.new(:method_not_found, message: "Method not found: #{rpc_method}")
        rescue JSON_RPC::JsonRpcError
          raise
        rescue StandardError => e
          Rails.logger.error "custom_method_handler error: #{e.class} - #{e.message}"
          raise JSON_RPC::JsonRpcError.new(:internal_error, message: "Custom method handler error")
        end
      end
    end
  end
end
