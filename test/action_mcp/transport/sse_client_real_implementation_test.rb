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

    # Completely stub the start method to avoid waiting for endpoint
    @client.define_singleton_method(:start) do
      # Don't try to establish a real connection
      @stop_requested = false

      # Important: Mark as connected without waiting
      @connection_mutex.synchronize do
        @connected = true
        @connection_error = nil
      end

      # No need to start the SSE thread
    end

    # Stub HTTP request handling
    @client.define_singleton_method(:send_message) do |json_rpc|
      @sent_messages << MultiJson.load(json_rpc)
      MockHttpResponse.new
    end

    @client.instance_variable_set(:@sent_messages, @sent_messages)

    # Ensure we're ready to send messages
    @client.instance_variable_set(:@endpoint_received, true)
    @client.instance_variable_set(:@post_url, "http://seuros.com/action_mcp")

    @received_messages = []
    @client.on_message do |msg|
      @received_messages << msg
    end
  end

  test "client completes full initialization flow" do
    # Start the client (uses our stubbed implementation)
    @client.start

    # Since we've stubbed start, we need to trigger the initialize request manually
    @client.send(:send_initial_capabilities)

    # Verify initialize request was sent
    initialize_request = @sent_messages.find { |msg| msg["method"] == "initialize" }
    assert_not_nil initialize_request, "Client should send initialize request"

    initialize_request["id"]

    assert_equal "2025-03-26", initialize_request["params"]["protocolVersion"]
    assert_not_nil initialize_request["params"]["capabilities"]
  end
end
