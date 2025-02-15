# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    Response = Data.define(:id, :result, :error) do
      def initialize(id:, result: nil, error: nil)
        validate_presence_of_result_or_error!(result, error)
        validate_absence_of_both_result_and_error!(result, error)

        super
      end

      def to_h
        {
          jsonrpc: "2.0",
          id: id,
          result: result,
          error: error
        }.compact
      end

      private

      def validate_presence_of_result_or_error!(result, error)
        raise ArgumentError, "Either result or error must be provided." if result.nil? && error.nil?
      end

      def validate_absence_of_both_result_and_error!(result, error)
        raise ArgumentError, "Both result and error cannot be provided simultaneously." if result && error
      end
    end
  end
end
