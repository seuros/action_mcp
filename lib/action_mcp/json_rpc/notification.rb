# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    Notification = Data.define(:method, :params) do
      def initialize(method:, params: nil)
        super
      end

      def to_h
        {
          jsonrpc: "2.0",
          method: method,
          params: params
        }.compact
      end
    end
  end
end
