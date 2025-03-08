# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    # Represents a JSON-RPC response.
    Response = Data.define(:id, :result, :error) do
      # Initializes a new Response.
      #
      # @param id [String, Numeric] The request identifier.
      # @param result [Object, nil] The result data (optional).
      # @param error [Object, nil] The error data (optional).
      # @raise [ArgumentError] if neither result nor error is provided, or if both are provided.
      def initialize(id:, result: nil, error: nil)
        validate_presence_of_result_or_error!(result, error)
        validate_absence_of_both_result_and_error!(result, error)
        result, error = transform_value_to_hash!(result, error)

        super(id: id, result: result, error: error)
      end

      # Returns a hash representation of the response.
      #
      # @return [Hash] The hash representation.
      def to_h
        {
          jsonrpc: "2.0",
          id: id,
          result: result,
          error: error
        }.compact
      end

      def is_error?
        error.present?
      end

      private

      # Validates that either result or error is present.
      #
      # @param result [Object, nil] The result data.
      # @param error [Object, nil] The error data.
      # @raise [ArgumentError] if neither result nor error is provided.
      def validate_presence_of_result_or_error!(result, error)
        raise ArgumentError, "Either result or error must be provided." if result.nil? && error.nil?
      end

      # Validates that both result and error are not present simultaneously.
      #
      # @param result [Object, nil] The result data.
      # @param error [Object, nil] The error data.
      # @raise [ArgumentError] if both result and error are provided.
      def validate_absence_of_both_result_and_error!(result, error)
        raise ArgumentError, "Both result and error cannot be provided simultaneously." if result && error
      end

      def transform_value_to_hash!(result, error)
        result = result.is_a?(String) ? (MultiJson.load(result) rescue result) : result
        error = error.is_a?(String) ? (MultiJson.load(error) rescue error) : error
        [ result, error ]
      end
    end
  end
end
