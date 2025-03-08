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

    @client = ActionMCP::Transport::SSEClient.new("http://seuros.com/action_mcp", logger: logger)

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
      # No need to wait for endpoint
    end

    # Stub HTTP request handling
    @client.define_singleton_method(:send_http_request) do |json_rpc|
      @sent_messages << JSON.parse(json_rpc)
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

    request_id = initialize_request["id"]

    assert_equal "2024-11-05", initialize_request["params"]["protocolVersion"]
    assert_not_nil initialize_request["params"]["capabilities"]

    # Create a capabilities response
    capabilities_response = ActionMCP::JsonRpc::Response.new(
      id: request_id,
      result: {
        "protocolVersion" => "2024-11-05",
        "serverInfo" => {
          "name" => "TestServer",
          "version" => "1.0.0"
        },
        "capabilities" => {
          "tools" => {}
        }
      }
    )

    # Process the response
    @client.send(:handle_raw_message, capabilities_response.to_json)

    # Verify initialized notification was sent
    initialized_notification = @sent_messages.find { |msg| msg["method"] == "notifications/initialized" }
    assert_not_nil initialized_notification, "Client should send initialized notification"

    # Verify sequence
    initialize_index = @sent_messages.index(initialize_request)
    initialized_index = @sent_messages.index(initialized_notification)
    assert initialize_index < initialized_index, "Initialize should be sent before initialized"
  end
end
