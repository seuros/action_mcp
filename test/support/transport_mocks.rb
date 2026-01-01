# frozen_string_literal: true

module TransportMocks
  # A minimal, deliberately fake TCP-ish session for use in specs.
  # It doesn't read, doesn't connect, and doesn't care — much like your average senior dev on a Friday.
  class DummySession
    attr_reader :written

    # Capture the data like it's a rare Pokémon.
    def write(data)  = @written = data
    # Input? Absolutely not. This is a write-only lifestyle.
    def read         = nil
    # Pretend everything's fine. It's faster that way.
    def initialize!  = true
    # We're *always* ready. Emotionally? Not so much.
    def initialized? = true

    def send_progress_notification(**params)
      handler = ActionMCP::Server::TransportHandler.new(self)
      handler.send_progress_notification(**params)
    end
  end

  class MockServerTransport
    attr_reader :sent_messages, :initialized

    def initialize
      @sent_messages = []
      @initialized = false
      @handlers = []
      @peer = nil
    end

    def connect(peer)
      @peer = peer
    end

    def on_message(&block)
      @handlers << block
    end

    def send_message(json)
      parsed = MultiJson.load(json)
      @sent_messages << parsed
      @peer&.receive_message(json)
    end

    def receive_message(json)
      parsed = MultiJson.load(json)
      send_capabilities_response(parsed["id"]) if parsed["method"] == "initialize"
      @initialized = true if parsed["method"] == "notifications/initialized"
      @handlers.each { |h| h.call(parsed) }
    end

    private

    # Sends a hardcoded capabilities payload. Basically a resumé, but JSONRPC
    def send_capabilities_response(request_id)
      resp = JSON_RPC::Response.new(
        id: request_id,
        result: {
          protocolVersion: "2025-06-18",
          serverInfo: { name: "TestServer", version: "1.0.0" },
          capabilities: {
            tools: { listChanged: false },
            prompts: { listChanged: false },
            resources: { subscribe: true, listChanged: false },
            logging: {}
          }
        }
      )
      send_message(resp.to_json)
    end
  end
end
