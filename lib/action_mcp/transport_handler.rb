# frozen_string_literal: true

module ActionMCP
  class TransportHandler
    include Logging

    include Transport::Capabilities
    include Transport::Tools
    include Transport::Prompts
    include Transport::Messaging

    HEARTBEAT_INTERVAL = 15 # seconds
    attr_reader :initialized

    def initialize(output_io)
      @output = output_io
      @output.sync = true if @output.respond_to?(:sync=)
      @initialized = false
      @client_capabilities = {}
      @client_info = {}
      @protocol_version = ""
    end

    def send_ping
      send_jsonrpc_request("ping")
    end

    def send_pong(request_id)
      send_jsonrpc_response(request_id, result: {})
    end

    def initialized?
      @initialized
    end

    def initialized!
      @initialized = true
    end

    private

    def write_message(data)
      @output.write(data)
    end

    def format_registry_items(registry)
      registry.map { |item| item.klass.to_h }
    end
  end
end
