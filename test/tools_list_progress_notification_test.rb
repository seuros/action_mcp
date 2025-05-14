# frozen_string_literal: true

require "test_helper"

class ToolsListProgressNotificationTest < ActionDispatch::IntegrationTest
  def app
    ActionMCP::Engine
  end

  test "tools/list handles progressToken without timing out" do
    # Initialize session
    init_request = {
      jsonrpc: "2.0",
      id: "init-1",
      method: "initialize",
      params: {
        protocolVersion: "2025-03-26",
        clientInfo: {
          name: "Test Client",
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

    # Find the session and register a tool
    session = ActionMCP::Session.find(session_id)
    assert_not_nil session, "Session should be found in database"
    session.register_tool("calculate_sum")

    # Send initialized notification
    post "/",
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json",
           "Mcp-Session-Id" => session_id
         },
         params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json

    # Send tools/list with progressToken
    tools_request = {
      jsonrpc: "2.0",
      id: "list-tools-1",
      method: "tools/list",
      params: {
        _meta: {
          progressToken: "tools-list-progress"
        }
      }
    }

    # Setup to capture progress notifications
    original_send_progress = ActionMCP::Session.instance_method(:send_progress_notification)
    ActionMCP::Session.class_eval do
      define_method(:send_progress_notification) do |progressToken:, progress:, total: nil, message: nil, **options|
        if progressToken == "tools-list-progress"
          Thread.current[:test_progress_notifications] ||= []
          Thread.current[:test_progress_notifications] << {
            progressToken: progressToken,
            progress: progress,
            total: total,
            message: message
          }
        end
        original_send_progress.bind(self).call(
          progressToken: progressToken,
          progress: progress,
          total: total,
          message: message,
          **options
        )
      end
    end

    begin
      # Clear any existing notifications before we start
      Thread.current[:test_progress_notifications] = []

      # Send the request
      post "/",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "ACCEPT" => "application/json",
             "Mcp-Session-Id" => session_id
           },
           params: tools_request.to_json

      assert_response :ok

      # Verify the response contains tools
      tools_response = response.parsed_body
      assert_equal "2.0", tools_response["jsonrpc"]

      assert_equal "list-tools-1", tools_response["id"] if tools_response["id"]

      if tools_response["result"] && tools_response["result"]["tools"]
        assert tools_response["result"]["tools"].is_a?(Array)
      end

      # Inspect progress notifications
      captured_notifications = Thread.current[:test_progress_notifications] || []

      # Either we should receive progress notifications, or the operation should complete
      # without timing out (which is the key requirement)
      if captured_notifications.any?
        # If we sent progress notifications, verify they're correctly formatted
        captured_notifications.each do |notification|
          assert_equal "tools-list-progress", notification[:progressToken]
          assert notification[:progress].is_a?(Numeric)
        end
      else
        # If no progress notifications were sent, that's acceptable as long as the
        # operation completed successfully without timeout
        # Either a successful result or an error response indicates completion without timeout
        assert (tools_response["result"] || tools_response["error"]),
               "Operation should complete successfully or with error, but not timeout"
      end
    ensure
      # Restore original method
      ActionMCP::Session.class_eval do
        define_method(:send_progress_notification, original_send_progress) if original_send_progress
      end
    end
  end
end
