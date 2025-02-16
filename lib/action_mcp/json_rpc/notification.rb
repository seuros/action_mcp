# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    # Represents a JSON-RPC notification.
    Notification = Data.define(:method, :params) do
      # Initializes a new Notification.
      #
      # @param method [String] The method name.
      # @param params [Hash, nil] The parameters (optional).
      def initialize(method:, params: nil)
        super
      end

      # Returns a hash representation of the notification.
      #
      # @return [Hash] The hash representation.
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
