# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    Request = Data.define(:jsonrpc, :id, :method, :params) do
      def initialize(id:, method:, params: nil)
        validate_id(id)
        super(id: id, method: method, params: params)
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
    end
  end
end
