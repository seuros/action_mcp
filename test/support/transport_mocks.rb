# frozen_string_literal: true

module TransportMocks
  # A minimal, deliberately fake TCP-ish session for use in specs.
  # It doesn’t read, doesn’t connect, and doesn’t care — much like your average senior dev on a Friday.
  class DummySession
    attr_reader :written

    def write(data)  = @written = data            # Capture the data like it's a rare Pokémon.
    def read         = nil                        # Input? Absolutely not. This is a write-only lifestyle.
    def initialize!  = true                       # Pretend everything's fine. It’s faster that way.
    def initialized? = true                       # We’re *always* ready. Emotionally? Not so much.

    def send_progress_notification(**params)
      handler = ActionMCP::Server::TransportHandler.new(self)
      handler.send_progress_notification(**params)
    end
  end

  # Client-side mock transport. Sends messages, receives callbacks, pretends to be productive.
  class MockClientTransport
    attr_reader :sent_messages, :initialized

    def initialize
      @sent_messages      = []
      @initialized        = false
      @handlers           = []
      @peer               = nil
      @initialize_req_id  = nil
    end

    # Connect to your imaginary peer. It’s not lonely if it’s test code.
    def connect(peer) = (@peer = peer)

    # ─── Communication helpers ────────────────────────────────────

    def send_message(json)
      parsed = MultiJson.load(json)
      @sent_messages << parsed
      @peer&.receive_message(json)
    end

    def receive_message(json)
      parsed = MultiJson.load(json)
      send_initialized_notification if parsed["id"] == @initialize_req_id
      @handlers.each { |h| h.call(parsed) }
    end

    # Register a handler for inbound messages. They're like tiny event listeners, but sadder.
    def on_message(&block) = (@handlers << block)

    # ─── Test-friendly helpers ────────────────────────────────────

    # Craft and send an initialize request. Yes, it’s fake. No, we’re not sorry.
    def send_initialize_request
      @initialize_req_id = "init-#{SecureRandom.hex(4)}"
      req = JSON_RPC::Request.new(
        id:     @initialize_req_id,
        method: "initialize",
        params: {
          protocolVersion: "2024-11-05",
          capabilities:    {},
          clientInfo:      { name: "TestClient", version: "1.0.0" }
        }
      )
      send_message(req.to_json)
      @initialize_req_id
    end

    # Announce that we've been initialized. Whether that's true is between us and our conscience.
    def send_initialized_notification
      note = JSON_RPC::Notification.new(method: "notifications/initialized")
      @initialized = true
      send_message(note.to_json)
    end
  end

  # Mock server-side counterpart. Stoic, reliable, and just as fake as the client.
  class MockClientTransport
    attr_reader :sent_messages, :initialized

    def initialize
      @sent_messages = []
      @initialized = false
      @handlers = []
      @peer = nil
      @initialize_req_id = nil
    end

    def connect(peer)
      @peer = peer
    end

    def send_message(json)
      parsed = MultiJson.load(json)
      @sent_messages << parsed
      @peer&.receive_message(json)
    end

    def receive_message(json)
      parsed = MultiJson.load(json)
      send_initialized_notification if parsed["id"] == @initialize_req_id
      @handlers.each { |h| h.call(parsed) }
    end

    def on_message(&block)
      @handlers << block
    end

    def send_initialize_request
      @initialize_req_id = "init-#{SecureRandom.hex(4)}"
      req = JSON_RPC::Request.new(
        id: @initialize_req_id,
        method: "initialize",
        params: {
          protocolVersion: "2024-11-05",
          capabilities: {},
          clientInfo: { name: "TestClient", version: "1.0.0" }
        }
      )
      send_message(req.to_json)
      @initialize_req_id
    end

    def send_initialized_notification
      note = JSON_RPC::Notification.new(method: "notifications/initialized")
      @initialized = true
      send_message(note.to_json)
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
        id:     request_id,
        result: {
          protocolVersion: "2024-11-05",
          serverInfo:      { name: "TestServer", version: "1.0.0" },
          capabilities:    {
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
