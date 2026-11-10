# frozen_string_literal: true

module ActionMCP
  module Server
    # Sends a prompt or tool result as a JSON-RPC error when it is a protocol error,
    # otherwise as the request result.
    module ResultResponse
      private

      def send_result_response(request_id, result)
        if result.is_error
          send_jsonrpc_response(request_id, error: result.to_h)
        else
          send_jsonrpc_response(request_id, result: result.to_h)
        end
      end
    end
  end
end
