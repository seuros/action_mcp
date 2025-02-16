# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    # Represents a JSON-RPC request.
    Request = Data.define(:id, :method, :params) do
      # Initializes a new Request.
      #
      # @param id [String, Numeric] The request identifier.
      # @param method [String] The method name.
      # @param params [Hash, nil] The parameters (optional).
      # @raise [JsonRpcError] if the ID is invalid.
      def initialize(id:, method:, params: nil)
        validate_id(id)
        super
      end

      # Returns a hash representation of the request.
      #
      # @return [Hash] The hash representation.
      def to_h
        hash = {
          jsonrpc: "2.0",
          id: id,
          method: method
        }
        hash[:params] = params if params
        hash
      end

      private

      # Validates the ID.
      #
      # @param id [Object] The ID to validate.
      # @raise [JsonRpcError] if the ID is invalid.
      def validate_id(id)
        unless id.is_a?(String) || id.is_a?(Numeric)
          raise JsonRpcError.new(:invalid_params,
                                 message: "ID must be a string or number")
        end
        raise JsonRpcError.new(:invalid_params, message: "ID must not be null") if id.nil?
      end
    end
  end
end
