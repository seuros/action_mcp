# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    Request = Data.define(:id, :method, :params) do
      def initialize(id:, method:, params: nil)
        validate_id(id)
        super
      end

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
