# frozen_string_literal: true

require_relative "response_collector"
require_relative "base_messaging"

module ActionMCP
  module Server
    class TransportHandler
      attr_reader :session

      delegate :initialize!, :initialized?, to: :session
      delegate :read, :write, to: :session
      include Logging

      include  MessagingService
      include  Capabilities
      include  Tools
      include  Prompts
      include  Resources
      include  Sampling
      include  Roots
      include  Elicitation
      include  ResponseCollector # Must be included last to override write_message

      # @param [ActionMCP::Session] session
      # @param messaging_mode [:write, :return] The mode for message handling
      def initialize(session, messaging_mode: :write)
        @session = session
        @messaging_mode = messaging_mode
        initialize_response_collector if messaging_mode == :return
      end

      def send_pong(request_id)
        send_jsonrpc_response(request_id, result: {})
      end

      private

      def format_registry_items(registry)
        registry.map { |item| item.klass.to_h }
      end
    end
  end
end
