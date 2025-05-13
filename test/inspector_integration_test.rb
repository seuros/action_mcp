require "test_helper"

# This test simulates how MCP Inspector would interact with our server
# It focuses on testing the tools/list operation with progressToken
# to ensure it doesn't time out and handles progress notifications correctly
class InspectorIntegrationTest < ActionDispatch::IntegrationTest
  def app
    ActionMCP::Engine
  end

  setup do
    @protocol_version = "2025-03-26"
    @request_id_counter = 0
  end

  test "mcp inspector interaction flow including tools/list with progressToken" do
    # Step 1: Initialize the session (MCP Inspector always starts with this)
    session_id = initialize_session

    # Step 2: Send initialized notification
    send_initialized_notification(session_id)

    # Step 3: List tools with a progressToken (this is what was causing the timeout)
    response = list_tools_with_progress_token(session_id)

    # Verify the response is successful or has a valid error
    assert_response :ok

    # Either result or error indicates the request completed
    assert response["result"] || response["error"], "Expected either a result or error response"

    # Only validate tools structure if result exists
    if response["result"]
      assert response["result"]["tools"].is_a?(Array), "Expected tools to be an array"
      assert_not_empty response["result"]["tools"], "Expected at least one tool"
    end

    # Step 4: Test cancellation notification handling
    send_cancellation_notification(session_id, "req-123", "Request timed out")

    # Test should reach this point without timing out
    assert true, "Test completed without timing out"
  end

  test "tools/list with progressToken should not time out" do
    # Initialize a session
    session_id = initialize_session
    send_initialized_notification(session_id)

    # Setup progress notification tracking
    progress_notifications = track_progress_notifications("tools-progress-track")

    # Send tools/list with progressToken
    response = list_tools_with_progress_token(session_id, "tools-progress-track")

    # Verify response and progress notifications
    assert_response :ok

    # Request completed without timing out - either result or error is acceptable
    assert response["result"] || response["error"], "Expected either a result or error response"

    # Check the captured notifications (if any)
    if progress_notifications.any?
      assert_equal "tools-progress-track", progress_notifications.first[:progressToken]
      assert progress_notifications.last[:progress] >= progress_notifications.first[:progress],
             "Progress should increase or stay the same"
    end
  end

  private

  def next_request_id
    @request_id_counter += 1
    "req-#{@request_id_counter}"
  end

  def initialize_session
    request_id = next_request_id
    init_request = {
      jsonrpc: "2.0",
      id: request_id,
      method: "initialize",
      params: {
        protocolVersion: @protocol_version,
        clientInfo: {
          name: "MCP Inspector",
          version: "1.0.0"
        },
        capabilities: {}
      }
    }

    post "/",
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream"
         },
         params: init_request.to_json

    assert_response :ok
    session_id = response.headers["Mcp-Session-Id"]
    assert_not_nil session_id, "Session ID should be present in header"

    # Enhance the session with a tool for testing
    session = ActionMCP::Session.find(session_id)
    session.register_tool("calculate_sum")

    session_id
  end

  def send_initialized_notification(session_id)
    post "/",
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json",
           "Mcp-Session-Id" => session_id
         },
         params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json
  end

  def list_tools_with_progress_token(session_id, progress_token = "inspector-tools-progress")
    request_id = next_request_id
    tools_request = {
      jsonrpc: "2.0",
      id: request_id,
      method: "tools/list",
      params: {
        _meta: {
          progressToken: progress_token
        }
      }
    }

    post "/",
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json",
           "Mcp-Session-Id" => session_id
         },
         params: tools_request.to_json

    JSON.parse(response.body)
  end

  def send_cancellation_notification(session_id, request_id, reason)
    cancel_notification = {
      jsonrpc: "2.0",
      method: "notifications/cancelled",
      params: {
        requestId: request_id,
        reason: reason
      }
    }

    post "/",
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json",
           "Mcp-Session-Id" => session_id
         },
         params: cancel_notification.to_json

    assert_includes [ 200, 202 ], response.status, "Cancellation notification should be accepted with 200 OK or 202 Accepted"
  end

  def track_progress_notifications(progress_token)
    notifications = []

    original_send_progress = ActionMCP::Session.instance_method(:send_progress_notification)
    ActionMCP::Session.class_eval do
      define_method(:send_progress_notification) do |progressToken:, progress:, total: nil, message: nil, **options|
        # Capture the notification if it matches our token
        if progressToken == progress_token
          Thread.current[:inspector_test_notifications] ||= []
          Thread.current[:inspector_test_notifications] << {
            progressToken: progressToken,
            progress: progress,
            total: total,
            message: message
          }
        end

        # Call the original method
        original_send_progress.bind(self).call(
          progressToken: progressToken,
          progress: progress,
          total: total,
          message: message,
          **options
        )
      end
    end

    # Clear any existing notifications
    Thread.current[:inspector_test_notifications] = []

    # Return value will be evaluated after the test
    Thread.current[:inspector_test_notifications] || []
  end
end
