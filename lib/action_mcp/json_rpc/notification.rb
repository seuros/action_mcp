# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    Notification = Data.define(:method, :params) do
      def initialize(method:, params: nil)
        super(method: method, params: params)
      end

      def to_h
        hash = {
          jsonrpc: "2.0",
          method: method
        }
        hash[:params] = params if params
        hash
      end
    end
  end
end
