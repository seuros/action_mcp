module ActionMCP
  module Transport
    module Messaging
      def send_jsonrpc_request(method, params: nil, id: SecureRandom.uuid_v7)
        request = JsonRpc::Request.new(id: id, method: method, params: params)
        write_message(request.to_json)
      end

      def send_jsonrpc_response(request_id, result: nil, error: nil)
        response = JsonRpc::Response.new(id: request_id, result: result, error: error)
        write_message(response.to_json)
      end

      def send_jsonrpc_notification(method, params = nil)
        notification = JsonRpc::Notification.new(method: method, params: params)
        write_message(notification.to_json)
      end
    end
  end
end
