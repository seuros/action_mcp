# frozen_string_literal: true

require "test_helper"
require "stringio"

class MCPInitializationFlowTest < ActiveSupport::TestCase
  # Mock classes to simulate both sides of the connection
  class MockClientTransport
    attr_reader :sent_messages, :initialized

    def initialize
      @sent_messages = []
      @initialized = false
      @message_handlers = []
      @server_transport = nil
      @initialize_request_id = nil
    end

    def connect_to_server(server_transport)
      @server_transport = server_transport
    end

    def send_message(message)
      parsed = JSON.parse(message)
      @sent_messages << parsed

      # Forward to server
      @server_transport&.receive_message(message)
    end

    def receive_message(message)
      parsed = JSON.parse(message)

      # If this is a response to an initialize request
      if parsed["id"] && @initialize_request_id && parsed["id"] == @initialize_request_id
        # Simulate client receiving server capabilities - next step is to send initialized
        send_initialized_notification
      end

      # Call any registered message handlers
      @message_handlers.each { |handler| handler.call(parsed) }
    end

    def on_message(&block)
      @message_handlers << block
    end

    def send_initialize_request
      # Important: Make sure to set the request ID BEFORE sending the message
      @initialize_request_id = "init-#{SecureRandom.hex(4)}"

      initialize_request = ActionMCP::JsonRpc::Request.new(
        id: @initialize_request_id,
        method: "initialize",
        params: {
          protocolVersion: "2024-11-05",
          capabilities: {},
          clientInfo: {
            name: "TestClient",
            version: "1.0.0"
          }
        }
      )

      send_message(initialize_request.to_json)
      @initialize_request_id
    end

    def send_initialized_notification
      initialized_notification = ActionMCP::JsonRpc::Notification.new(
        method: "notifications/initialized"
      )

      @initialized = true
      send_message(initialized_notification.to_json)
    end
  end

  class MockServerTransport
    attr_reader :sent_messages, :initialized

    def initialize
      @sent_messages = []
      @initialized = false
      @message_handlers = []
      @client_transport = nil
    end

    def connect_to_client(client_transport)
      @client_transport = client_transport
    end

    def send_message(message)
      parsed = JSON.parse(message)
      @sent_messages << parsed

      # Forward to client
      @client_transport&.receive_message(message)
    end

    def receive_message(message)
      parsed = JSON.parse(message)

      # If this is an initialize request, send capabilities response
      send_capabilities_response(parsed["id"]) if parsed["method"] == "initialize"

      # If this is an initialized notification, mark as initialized
      @initialized = true if parsed["method"] == "notifications/initialized"

      # Call any registered message handlers
      @message_handlers.each { |handler| handler.call(parsed) }
    end

    def on_message(&block)
      @message_handlers << block
    end

    def send_capabilities_response(request_id)
      capabilities_response = ActionMCP::JsonRpc::Response.new(
        id: request_id,
        result: {
          protocolVersion: "2024-11-05",
          serverInfo: {
            name: "TestServer",
            version: "1.0.0"
          },
          capabilities: {
            tools: { listChanged: false },
            prompts: { listChanged: false },
            resources: { subscribe: true, listChanged: false },
            logging: {}
          }
        }
      )

      send_message(capabilities_response.to_json)
    end
  end

  def setup
    @client_transport = MockClientTransport.new
    @server_transport = MockServerTransport.new

    # Connect the transports to each other
    @client_transport.connect_to_server(@server_transport)
    @server_transport.connect_to_client(@client_transport)

    # Set up message capture for verification
    @client_messages = []
    @server_messages = []

    @client_transport.on_message do |msg|
      @client_messages << msg
    end

    @server_transport.on_message do |msg|
      @server_messages << msg
    end
  end

  test "completes full initialization flow" do
    # Start with empty message queues
    assert_equal 0, @client_transport.sent_messages.size, "Client should start with empty message queue"
    assert_equal 0, @server_transport.sent_messages.size, "Server should start with empty message queue"

    # 1. Client sends initialize request
    request_id = @client_transport.send_initialize_request

    # Get messages in the order they were sent
    all_client_messages = @client_transport.sent_messages
    all_server_messages = @server_transport.sent_messages

    # Verify initialize was sent first
    initialize_msg = all_client_messages.find { |msg| msg["method"] == "initialize" }
    assert_not_nil initialize_msg, "Client should have sent initialize request"
    assert_equal request_id, initialize_msg["id"], "Initialize request ID should match"

    # Verify server response
    response_msg = all_server_messages.find { |msg| msg["id"] == request_id }
    assert_not_nil response_msg, "Server should have responded to initialize request"
    assert_not_nil response_msg["result"], "Response should include result"
    assert_not_nil response_msg["result"]["capabilities"], "Response should include capabilities"

    # Verify initialized notification was sent
    initialized_msg = all_client_messages.find { |msg| msg["method"] == "notifications/initialized" }
    assert_not_nil initialized_msg, "Client should have sent initialized notification"

    # Verify server marked as initialized
    assert @server_transport.initialized, "Server should be marked as initialized"

    # Verify client marked as initialized
    assert @client_transport.initialized, "Client should be marked as initialized"

    # Verify message sequence
    # Rather than checking array positions, verify logical sequence using timestamps
    initialize_index = all_client_messages.index(initialize_msg)
    initialized_index = all_client_messages.index(initialized_msg)
    assert initialize_index < initialized_index,
           "Initialize request should be sent before initialized notification"
  end
end
