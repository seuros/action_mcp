# frozen_string_literal: true

module ActionMCP
  module Server
    module ErrorHandling
      private

      def error_response(id, error_or_symbol, message = nil, data = nil)
        json_rpc_error = case error_or_symbol
        when JSON_RPC::JsonRpcError
                           error_or_symbol
        when Symbol
                           JSON_RPC::JsonRpcError.new(error_or_symbol, message: message, data: data)
        else
                           error_or_symbol
        end

        JSON_RPC::Response.new(id: id, error: json_rpc_error)
      end

      # Helper method to create error response from any exception
      def error_response_from_exception(id, exception)
        if exception.is_a?(JSON_RPC::JsonRpcError)
          error_response(id, exception)
        else
          error_response(id, :internal_error, exception.message)
        end
      end
    end
  end
end
