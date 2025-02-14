# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    class JsonRpcError < StandardError
      # Define the standard JSON-RPC 2.0 error codes
      ERROR_CODES = {
        parse_error: {
          code: -32_700,
          message: "Parse error"
        },
        invalid_request: {
          code: -32_600,
          message: "Invalid request"
        },
        method_not_found: {
          code: -32_601,
          message: "Method not found"
        },
        invalid_params: {
          code: -32_602,
          message: "Invalid params"
        },
        internal_error: {
          code: -32_603,
          message: "Internal error"
        },
        server_error: {
          code: -32_000,
          message: "Server error"
        }
      }.freeze

      attr_reader :code, :data

      # Retrieve error details by symbol.
      def self.[](symbol)
        ERROR_CODES[symbol] or raise ArgumentError, "Unknown error code: #{symbol}"
      end

      # Build an error hash, allowing custom message or data to override defaults.
      def self.build(symbol, message: nil, data: nil)
        error = self[symbol].dup
        error[:message] = message if message
        error[:data] = data if data
        error
      end

      # Initialize the error using a symbol key, with optional custom message and data.
      def initialize(symbol, message: nil, data: nil)
        error_details = self.class.build(symbol, message: message, data: data)
        @code = error_details[:code]
        @data = error_details[:data]
        super(error_details[:message])
      end

      # Returns a hash formatted for a JSON-RPC error response.
      def as_json
        hash = { code: code, message: message }
        hash[:data] = data if data
        hash
      end

      # Converts the error hash to a JSON string.
      def to_json(*_args)
        MultiJson.dump(as_json, *args)
      end
    end
  end
end
