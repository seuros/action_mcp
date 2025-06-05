# frozen_string_literal: true

require "test_helper"
require "stringio"

class SSEClientRealImplementationTest < ActiveSupport::TestCase
  # Simple mock HTTP response class
  class MockHttpResponse
    def success?
      true
    end
  end

  def setup
    @log_output = StringIO.new
    logger = Logger.new(@log_output)
    logger.level = Logger::ERROR

    @client = ActionMCP.create_client("http://seuros.com/action_mcp", logger: logger, connect: false)

    @sent_messages = []
    @received_messages = []

    # Get the transport from the client
    transport = @client.transport

    # Stub the transport's connect method
    transport.define_singleton_method(:connect) do
      @connected = true
      true
    end

    # Stub the transport's ready? method
    transport.define_singleton_method(:ready?) do
      true
    end

    # Stub the transport's send_message method to capture sent messages
    sent_messages = @sent_messages
    transport.define_singleton_method(:send_message) do |json_rpc|
      sent_messages << MultiJson.load(json_rpc)
      true
    end

    # Access the transport's message callback to simulate receiving messages
    @transport_message_callback = nil
    transport.define_singleton_method(:on_message) do |&block|
      @transport_message_callback = block
    end

    # Re-setup transport callbacks to capture the callback
    @client.send(:setup_transport_callbacks)

    # Store the callback reference
    @transport_message_callback = transport.instance_variable_get(:@transport_message_callback)
  end

  test "client completes full initialization flow" do
    # Connect the client (uses our stubbed transport)
    @client.connect

    # Trigger the initialize request manually
    @client.send(:send_initial_capabilities)

    # Verify initialize request was sent
    initialize_request = @sent_messages.find { |msg| msg["method"] == "initialize" }
    assert_not_nil initialize_request, "Client should send initialize request"

    initialize_request["id"]

    assert_equal "2025-03-26", initialize_request["params"]["protocolVersion"]
    assert_not_nil initialize_request["params"]["capabilities"]
  end
end
