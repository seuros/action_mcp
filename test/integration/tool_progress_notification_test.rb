# frozen_string_literal: true

require "test_helper"

class ToolProgressNotificationTest < ActionDispatch::IntegrationTest
  include ActionMCP::TestHelper

  def app
    ActionMCP::Engine
  end

  setup do
    # Use test session store
    @original_store = ActionMCP::Server.session_store
    @test_store = ActionMCP::Server::TestSessionStore.new
    ActionMCP::Server.instance_variable_set(:@session_store, @test_store)
  end

  teardown do
    # Reset the test store
    @test_store.reset_tracking! if @test_store.respond_to?(:reset_tracking!)
    # Restore original store
    ActionMCP::Server.instance_variable_set(:@session_store, @original_store)
  end

  test "tool sends progress notifications when progressToken is provided" do
    # Verify we're using the test store
    assert_instance_of ActionMCP::Server::TestSessionStore, ActionMCP::Server.session_store

    session_id = create_initialized_session


    # Set up notification tracking
    notifications_received = []
    @test_store.on_notification do |notification|
      notifications_received << notification if notification.method == "notifications/progress"
    end

    # Call tool with progressToken
    request_payload = {
      jsonrpc: "2.0",
      id: "tool-1",
      method: "tools/call",
      params: {
        name: "progress_2025_demo",
        arguments: {
          total_items: 3,
          delay_ms: 1
        },
        _meta: {
          progressToken: "integration-test-123"
        }
      }
    }

    post "/",
         headers: default_json_headers.merge("Mcp-Session-Id" => session_id),
         params: request_payload.to_json

    assert_response :success

    # Verify response structure
    response_body = response.parsed_body
    assert_equal "tool-1", response_body["id"]

    # Check for error
    if response_body["error"]
      puts "Error response: #{response_body['error'].inspect}"
    end

    assert_not_nil response_body["result"], "Expected result but got: #{response_body.inspect}"

    # Check content
    content = response_body.dig("result", "content")
    assert_not_nil content
    assert_not_empty content

    text_content = content.find { |c| c["type"] == "text" }
    assert_not_nil text_content
    assert_includes text_content["text"], "Processed item"


    # Verify progress notifications were sent
    assert_progress_notification_sent("integration-test-123")
    assert_progress_notification_count("integration-test-123", 3)
    assert_progress_sequence_valid("integration-test-123")

    # Check notification details
    assert_progress_notification_includes("integration-test-123", {
      progress: 3,
      total: 3
    })
  end

  test "tool works without progressToken" do
    session_id = create_initialized_session

    # Track notifications
    @test_store.on_notification do |notification|
      # Should not receive any progress notifications
      refute_equal "notifications/progress", notification.method
    end

    # Call tool without progressToken
    request_payload = {
      jsonrpc: "2.0",
      id: "tool-2",
      method: "tools/call",
      params: {
        name: "progress_2025_demo",
        arguments: {
          total_items: 2,
          delay_ms: 1
        }
        # No _meta with progressToken
      }
    }

    post "/",
         headers: default_json_headers.merge("Mcp-Session-Id" => session_id),
         params: request_payload.to_json

    assert_response :success

    # Tool should complete successfully
    response_body = response.parsed_body
    assert_equal "tool-2", response_body["id"]
    assert_not_nil response_body["result"]

    # No progress notifications should have been sent
    assert_equal 0, @test_store.notifications_sent.size
  end

  test "multiple tools can send progress concurrently" do
    session_id = create_initialized_session

    tokens = [ "concurrent-1", "concurrent-2", "concurrent-3" ]
    threads = []

    # Start multiple tool calls concurrently
    tokens.each_with_index do |token, index|
      threads << Thread.new do
        request = {
          jsonrpc: "2.0",
          id: "concurrent-#{index}",
          method: "tools/call",
          params: {
            name: "progress_2025_demo",
            arguments: {
              total_items: 2,
              delay_ms: 10
            },
            _meta: {
              progressToken: token
            }
          }
        }

        post "/",
             headers: default_json_headers.merge("Mcp-Session-Id" => session_id),
             params: request.to_json
      end
    end

    # Wait for all requests to complete
    threads.each(&:join)

    # Verify each tool sent its notifications
    tokens.each do |token|
      assert_progress_notification_sent(token)
      assert_progress_notification_count(token, 2)
      assert_progress_sequence_valid(token)
    end

    # Total notifications should be 6 (3 tools × 2 notifications each)
    assert_equal 6, @test_store.notifications_sent.size
  end

  test "invalid tool handles progress token gracefully" do
    session_id = create_initialized_session

    # Call non-existent tool with progress token
    request_payload = {
      jsonrpc: "2.0",
      id: "invalid-tool",
      method: "tools/call",
      params: {
        name: "non_existent_tool",
        arguments: {},
        _meta: {
          progressToken: "should-not-be-used"
        }
      }
    }

    post "/",
         headers: default_json_headers.merge("Mcp-Session-Id" => session_id),
         params: request_payload.to_json

    assert_response :success

    # Should get an error response
    response_body = response.parsed_body
    assert_not_nil response_body["error"]

    # No progress notifications should have been sent
    assert_no_progress_notification_sent("should-not-be-used")
  end

  test "progress notifications include custom message" do
    session_id = create_initialized_session

    # Call tool that sends progress with messages
    request_payload = {
      jsonrpc: "2.0",
      id: "message-test",
      method: "tools/call",
      params: {
        name: "progress_2025_demo",
        arguments: {
          total_items: 1,
          delay_ms: 1
        },
        _meta: {
          progressToken: "message-test-token"
        }
      }
    }

    post "/",
         headers: default_json_headers.merge("Mcp-Session-Id" => session_id),
         params: request_payload.to_json

    assert_response :success

    # Check notification has message
    notifications = @test_store.notifications_for_token("message-test-token")
    assert_equal 1, notifications.size

    notification = notifications.first
    assert notification.params.key?(:message)
    assert_includes notification.params[:message], "Processing"
    assert_includes notification.params[:message], "item_1"
  end

  private

  def create_initialized_session
    # Initialize the session
    init_request = {
      jsonrpc: "2.0",
      id: "init-1",
      method: "initialize",
      params: {
        protocolVersion: "2025-03-26",
        capabilities: {},
        clientInfo: { name: "Test Client", version: "1.0" }
      }
    }

    post "/",
         headers: default_json_headers,
         params: init_request.to_json

    assert_response :ok
    session_id = response.headers["Mcp-Session-Id"]
    assert_not_nil session_id, "Session ID should be in response headers"

    # Register the progress demo tool for the session
    session = @test_store.load_session(session_id)
    session.register_tool("progress_2025_demo")

    # Send initialized notification
    initialized_notification = {
      jsonrpc: "2.0",
      method: "notifications/initialized"
    }

    post "/",
         headers: default_json_headers.merge("Mcp-Session-Id" => session_id),
         params: initialized_notification.to_json

    assert_response :accepted

    session_id
  end

  def default_json_headers
    {
      "CONTENT_TYPE" => "application/json",
      "ACCEPT" => "application/json"
    }
  end
end
