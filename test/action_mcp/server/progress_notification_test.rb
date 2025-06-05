# frozen_string_literal: true

require "test_helper"

class ProgressNotificationTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper
  
  setup do
    # Use test session store
    @original_store = ActionMCP::Server.session_store
    @test_store = ActionMCP::Server::TestSessionStore.new
    ActionMCP::Server.instance_variable_set(:@session_store, @test_store)
    
    # Create a session
    @session = @test_store.create_session("test-session-123")
    @session.initialized = true
    @session.status = "initialized"
    
    # Create transport handler
    @transport = ActionMCP::Server::TransportHandler.new(@session)
  end
  
  teardown do
    ActionMCP::Server.instance_variable_set(:@session_store, @original_store)
  end
  
  test "sends progress notification with all fields" do
    @transport.send_progress_notification(
      progressToken: "task-123",
      progress: 50,
      total: 100,
      message: "Processing item 50 of 100"
    )
    
    assert_progress_notification_sent("task-123")
    assert_progress_notification_includes("task-123", {
      progress: 50,
      total: 100,
      message: "Processing item 50 of 100"
    })
  end
  
  test "sends progress notification with only required fields" do
    @transport.send_progress_notification(
      progressToken: "minimal-test",
      progress: 25
    )
    
    notifications = @test_store.notifications_for_token("minimal-test")
    assert_equal 1, notifications.length
    
    notification = notifications.first
    params = notification.params
    
    # Required fields are present
    assert_equal "minimal-test", params[:progressToken]
    assert_equal 25, params[:progress]
    
    # Optional fields are not included
    assert_not params.key?(:total)
    assert_not params.key?(:message)
  end
  
  test "notification structure follows MCP spec" do
    @transport.send_progress_notification(
      progressToken: "spec-test",
      progress: 75,
      total: 100
    )
    
    notifications = @test_store.notifications_for_token("spec-test")
    assert_equal 1, notifications.length
    
    notification = notifications.first
    assert_progress_notification_valid(notification)
  end
  
  test "progress values must increase monotonically" do
    token = "sequence-test"
    
    [ 0, 25, 50, 75, 100 ].each do |progress|
      @transport.send_progress_notification(
        progressToken: token,
        progress: progress,
        total: 100
      )
    end
    
    assert_progress_sequence_valid(token)
    assert_progress_notification_count(token, 5)
  end
  
  test "supports integer progress tokens" do
    @transport.send_progress_notification(
      progressToken: 12345,
      progress: 50
    )
    
    notifications = @test_store.notifications_for_token(12345)
    assert_equal 1, notifications.length
    assert_equal 12345, notifications.first.params[:progressToken]
  end
  
  test "notification callbacks are triggered" do
    callback_invoked = false
    received_notification = nil
    
    @test_store.on_notification do |notification|
      callback_invoked = true
      received_notification = notification
    end
    
    @transport.send_progress_notification(
      progressToken: "callback-test",
      progress: 42
    )
    
    assert callback_invoked, "Callback should have been invoked"
    assert_not_nil received_notification
    assert_equal "callback-test", received_notification.params[:progressToken]
    assert_equal 42, received_notification.params[:progress]
  end
  
  test "multiple callbacks can be registered" do
    callback_count = 0
    
    3.times do
      @test_store.on_notification { callback_count += 1 }
    end
    
    @transport.send_progress_notification(
      progressToken: "multi-callback",
      progress: 10
    )
    
    assert_equal 3, callback_count
  end
  
  test "clear_notifications removes all notifications" do
    # Send some notifications
    3.times do |i|
      @transport.send_progress_notification(
        progressToken: "clear-test",
        progress: i * 10
      )
    end
    
    assert_equal 3, @test_store.notifications_sent.size
    
    @test_store.clear_notifications
    
    assert_equal 0, @test_store.notifications_sent.size
    assert_empty @test_store.notifications_for_token("clear-test")
  end
  
  test "reset_tracking! clears notifications and callbacks" do
    # Add notification and callback
    @test_store.on_notification { }
    @transport.send_progress_notification(
      progressToken: "reset-test",
      progress: 50
    )
    
    assert_equal 1, @test_store.notifications_sent.size
    assert_equal 1, @test_store.instance_variable_get(:@notification_callbacks).size
    
    @test_store.reset_tracking!
    
    assert_equal 0, @test_store.notifications_sent.size
    assert_equal 0, @test_store.instance_variable_get(:@notification_callbacks).size
  end
  
  test "handles nil message gracefully" do
    @transport.send_progress_notification(
      progressToken: "nil-message",
      progress: 50,
      total: 100,
      message: nil
    )
    
    notifications = @test_store.notifications_for_token("nil-message")
    params = notifications.first.params
    
    assert_not params.key?(:message), "Nil message should not be included"
  end
  
  test "handles empty message as valid" do
    @transport.send_progress_notification(
      progressToken: "empty-message",
      progress: 50,
      message: ""
    )
    
    notifications = @test_store.notifications_for_token("empty-message")
    params = notifications.first.params
    
    # Empty string is not "present?" so should be excluded
    assert_not params.key?(:message), "Empty message should not be included"
  end
  
  test "assertion helper raises helpful error with wrong store type" do
    # Switch to a non-test store temporarily
    ActionMCP::Server.instance_variable_set(:@session_store, ActionMCP::Server::VolatileSessionStore.new)
    
    error = assert_raises(RuntimeError) do
      assert_progress_notification_sent("any-token")
    end
    
    assert_includes error.message, "does not support notification tracking"
    assert_includes error.message, "Use TestSessionStore"
  end
end