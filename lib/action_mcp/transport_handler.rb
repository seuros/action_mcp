# frozen_string_literal: true

module ActionMCP
  class TransportHandler
    attr_reader :session
    delegate :initialize!, :initialized?, to: :session
    delegate :read, :write, to: :session
    include Logging

    include Transport::Capabilities
    include Transport::Tools
    include Transport::Prompts
    include Transport::Messaging

    HEARTBEAT_INTERVAL = 15 # seconds

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
