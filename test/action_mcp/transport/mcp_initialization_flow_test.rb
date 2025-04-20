# frozen_string_literal: true

require "test_helper"

class MCPInitializationFlowTest < ActiveSupport::TestCase
  include TransportMocks
  def setup
    @client_transport = MockClientTransport.new
    @server_transport = MockServerTransport.new

    # Connect the transports to each other
    @client_transport.connect(@server_transport)
    @server_transport.connect(@client_transport)

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
