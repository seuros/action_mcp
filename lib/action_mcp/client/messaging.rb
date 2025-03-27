# frozen_string_literal: true

module ActionMCP
  module Client
    module Messaging
      def send_jsonrpc_request(method, params: nil, id: SecureRandom.uuid_v7)
        request = JSON_RPC::Request.new(id: id, method: method, params: params)
        write_message(request)
      end

      def send_jsonrpc_response(request_id, result: nil, error: nil)
        response = JSON_RPC::Response.new(id: request_id, result: result, error: error)
        write_message(response)
      end

      def send_jsonrpc_notification(method, params = nil)
        notification = JSON_RPC::Notification.new(method: method, params: params)
        write_message(notification)
      end

      def send_jsonrpc_error(request_id, symbol, message, data = nil)
        error = JSON_RPC::JsonRpcError.new(symbol, message:, data:)
        response = JSON_RPC::Response.new(id: request_id, error:)
        write_message(response)
      end
    end
  end
end
