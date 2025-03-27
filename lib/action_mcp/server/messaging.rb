# frozen_string_literal: true

module ActionMCP
  module Server
    module Messaging
      def send_jsonrpc_request(method, params: nil, id: SecureRandom.uuid_v7)
        send_message(:request, method: method, params: params, id: id)
      end

      def send_jsonrpc_response(request_id, result: nil, error: nil)
        send_message(:response, id: request_id, result: result, error: error)
      end

      def send_jsonrpc_notification(method, params = nil)
        send_message(:notification, method: method, params: params)
      end

      def send_jsonrpc_error(request_id, symbol, message, data = nil)
        error = JSON_RPC::JsonRpcError.new(symbol, message: message, data: data)
        send_jsonrpc_response(request_id, error: error)
      end

      private

      # Factory method to create and send appropriate JSON-RPC message
      def send_message(type, **args)
        message = case type
        when :request
                    JSON_RPC::Request.new(
                      id: args[:id],
                      method: args[:method],
                      params: args[:params]
                    )
        when :response
                    JSON_RPC::Response.new(
                      id: args[:id],
                      result: args[:result],
                      error: args[:error]
                    )
        when :notification
                    JSON_RPC::Notification.new(
                      method: args[:method],
                      params: args[:params]
                    )
        end

        write_message(message)
      end
    end
  end
end
