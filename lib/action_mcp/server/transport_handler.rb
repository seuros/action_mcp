# frozen_string_literal: true

module ActionMCP
  module Server
    class TransportHandler
      attr_reader :session

      delegate :initialize!, :initialized?, to: :session
      delegate :read, :write, to: :session
      include Logging

      include  Messaging
      include  Capabilities
      include  Tools
      include  Prompts
      include  Resources
      include  Notifications
      include  Sampling
      include  Roots

      # @param [ActionMCP::Session] session
      def initialize(session)
        @session = session
      end

      def send_pong(request_id)
        send_jsonrpc_response(request_id, result: {})
      end

      private

      def write_message(data)
        session.write(data)
      end

      def format_registry_items(registry)
        registry.map { |item| item.klass.to_h }
      end
    end
  end
end
