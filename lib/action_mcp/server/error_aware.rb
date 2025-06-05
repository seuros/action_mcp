# frozen_string_literal: true

module ActionMCP
  module Server
    module ErrorAware
      private

      # Validate required parameter and raise error if missing
      def validate_required_param(params, key, error_message)
        value = params[key] || params[key.to_sym]
        raise JSON_RPC::JsonRpcError.new(:invalid_params, message: error_message) if value.nil?

        value
      end

      # Validate params is not nil or empty
      def validate_params_present(params, error_message)
        raise JSON_RPC::JsonRpcError.new(:invalid_params, message: error_message) if params.nil? || params.empty?

        params
      end

      # Safe execution with JSON-RPC error handling
      def with_error_handling(request_id)
        yield
      rescue JSON_RPC::JsonRpcError => e
        if transport.messaging_mode == :return
          response = error_response(request_id, e)
          transport.write_message(response)
          response
        else
          transport.send_jsonrpc_response(request_id, error: e)
          nil
        end
      end
    end
  end
end
