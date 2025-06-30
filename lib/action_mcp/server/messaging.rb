# frozen_string_literal: true

module ActionMCP
  module Server
    module Messaging
      # Operation mode for the messaging module
      # :write - writes messages directly (default, for SSE)
      # :return - returns messages without writing (for JSON responses)
      attr_accessor :messaging_mode

      def send_jsonrpc_request(method, params: nil, id: SecureRandom.uuid_v7)
        send_message(:request, method: method, params: params, id: id)
      end

      def send_jsonrpc_response(request_id, result: nil, error: nil)
        # Only pass the parameters that are actually provided
        args = { id: request_id }
        args[:result] = result unless result.nil?
        args[:error] = error unless error.nil?
        send_message(:response, **args)
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
                    # Pass only the provided parameters to avoid validation errors
                    response_args = { id: args[:id] }
                    response_args[:result] = args[:result] if args.key?(:result)
                    response_args[:error] = args[:error] if args.key?(:error)
                    JSON_RPC::Response.new(**response_args)
        when :notification
                    JSON_RPC::Notification.new(
                      method: args[:method],
                      params: args[:params]
                    )
        end

        if messaging_mode == :return
          write_message(message)  # This will be intercepted by ResponseCollector
          message
        else
          write_message(message)
          nil
        end
      end
    end
  end
end
