# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    Response = Data.define(:id, :result, :error) do
      def initialize(id:, result: nil, error: nil)
        processed_error = process_error(error)
        processed_result = error ? nil : result
        validate_result_error!(processed_result, processed_error)
        super(id: id, result: processed_result, error: processed_error)
      end

      def to_h
        hash = {
          jsonrpc: "2.0",
          id: id
        }
        if error
          hash[:error] = {
            code: error[:code],
            message: error[:message]
          }
          hash[:error][:data] = error[:data] if error[:data]
        else
          hash[:result] = result
        end
        hash
      end

      private

      def process_error(error)
        case error
        when Symbol
          ErrorCodes[error]
        when Hash
          validate_error!(error)
          error
        end
      end

      def validate_error!(error)
        raise Error, "Error code must be an integer" unless error[:code].is_a?(Integer)
        raise Error, "Error message is required" unless error[:message].is_a?(String)
      end

      def validate_result_error!(result, error)
        raise Error, "Either result or error must be set" unless result || error
        raise Error, "Cannot set both result and error" if result && error
      end
    end
  end
end
