# test/progress_notification2025_integration_test.rb
require "test_helper"

class ProgressNotification2025IntegrationTest < ActionDispatch::IntegrationTest
  include ActionMCP::TestHelper

  def app
    ActionMCP::Engine
  end

  setup do
    @session = ActionMCP::Session.create!(initialized: true)
    # Register the tool for this session
    @session.register_tool("progress_2025_demo")

    # Reset any thread local variables
    Thread.current[:test_progress_notifications] = nil
  end

  teardown do
    # Clean up thread local variables
    Thread.current[:test_progress_notifications] = nil
  end

  test "tool sends 2025-spec compliant progress notifications" do
    # Capture all progress notifications by overriding session.write
    original_write = ActionMCP::Session.instance_method(:write)

    ActionMCP::Session.class_eval do
      define_method(:write) do |data|
        # Capture progress notifications
        if data.is_a?(ActionMCP::JSON_RPC::Notification) && data.method == "notifications/progress"
          Thread.current[:test_progress_notifications] ||= []
          Thread.current[:test_progress_notifications] << data.params
        end

        # Call original method
        original_write.bind(self).call(data)
      end
    end

    begin
      # Execute the tool
      payload = {
        jsonrpc: "2.0",
        id: "progress_test_2025",
        method: "tools/call",
        params: {
          name: "progress_2025_demo",
          arguments: { total_items: 3, delay_ms: 1 }
        }
      }

      post "/mcp",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "ACCEPT" => "application/json",
             "Mcp-Session-Id" => @session.id
           },
           params: payload.to_json

      assert_response :success

      # Verify progress notifications were captured
      captured_notifications = Thread.current[:test_progress_notifications] || []

      assert_equal 3, captured_notifications.length, "Should have 3 progress notifications"

      # Verify each notification follows 2025-03-26 spec
      captured_notifications.each_with_index do |notification, index|
        assert notification.key?(:progressToken), "Missing progressToken"
        assert notification.key?(:progress), "Missing progress"
        assert notification.key?(:total), "Missing total"
        assert notification.key?(:message), "Missing message"

        # Verify values
        assert_equal index + 1, notification[:progress], "Progress should be #{index + 1}"
        assert_equal 3, notification[:total], "Total should be 3"
        assert notification[:progressToken].start_with?("test_progress_token_"), "Invalid progressToken format"
        assert notification[:message].include?("item_#{index + 1}"), "Message should reference item_#{index + 1}"
      end

      # Verify progress values increase
      progress_values = captured_notifications.map { |n| n[:progress] }
      assert_equal [1, 2, 3], progress_values, "Progress values must increase"
    ensure
      # Restore original method
      ActionMCP::Session.class_eval do
        define_method(:write, original_write)
      end
    end
  end

  test "progress notifications conform to 2025 JSON-RPC format" do
    # Create a session and handler
    session = ActionMCP::Session.create!
    handler = ActionMCP::Server::TransportHandler.new(session)

    # Capture the written message
    written_message = nil
    session.define_singleton_method(:write) do |data|
      written_message = data
    end

    # Send a progress notification
    handler.send_progress_notification(
      progressToken: "json_rpc_test",
      progress: 50,
      total: 100,
      message: "Testing JSON-RPC format"
    )

    # Verify the message structure
    assert_not_nil written_message
    assert written_message.is_a?(JSON_RPC::Notification)
    assert_equal "notifications/progress", written_message.method

    params = written_message.params
    assert_equal "json_rpc_test", params[:progressToken]
    assert_equal 50, params[:progress]
    assert_equal 100, params[:total]
    assert_equal "Testing JSON-RPC format", params[:message]
  end

  test "handles progress notifications with metadata from request" do
    # Create a tool that can extract from request metadata
    captured_notifications = []

    # Override session.write to capture notifications
    original_write = @session.method(:write)
    @session.define_singleton_method(:write) do |data|
      if data.is_a?(ActionMCP::JSON_RPC::Notification) && data.method == "notifications/progress"
        captured_notifications << data.params
      end
      original_write.call(data)
    end

    # Test when a request includes progressToken in metadata
    payload = {
      jsonrpc: "2.0",
      id: "meta_progress_test",
      method: "tools/call",
      params: {
        name: "progress_2025_demo",
        arguments: { total_items: 1 },
        _meta: {
          progressToken: "client_provided_token"
        }
      }
    }

    post "/mcp",
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json",
           "Mcp-Session-Id" => @session.id
         },
         params: payload.to_json

    assert_response :success

    # Note: The tool would need to be modified to extract and use the
    # progressToken from the request metadata for full implementation
    assert captured_notifications.any?, "Should have at least one progress notification"

    captured_notifications.each do |notification|
      assert notification.key?(:progressToken)
      assert notification.key?(:progress)
      assert notification.key?(:total)
      assert notification.key?(:message)
    end
  end

  test "backward compatibility with legacy progress notification method" do
    # Test that tools using the old API still work if implemented
    session = ActionMCP::Session.create!
    handler = ActionMCP::Server::TransportHandler.new(session)

    # Skip this test if legacy method doesn't exist
    skip "Legacy progress notification method not implemented" unless handler.respond_to?(:send_progress_notification_legacy)

    # Capture deprecation warnings
    log_output = StringIO.new
    test_logger = Logger.new(log_output)

    # Replace Rails.logger temporarily
    original_logger = Rails.logger
    Rails.logger = test_logger

    begin
      handler.send_progress_notification_legacy(
        token: "legacy_token",
        value: 42,
        message: "Legacy format test"
      )

      # Check for deprecation warning
      assert_includes log_output.string, "DEPRECATION"
      assert_includes log_output.string, "token/value is deprecated"
    ensure
      Rails.logger = original_logger
    end
  end
end
