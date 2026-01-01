# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class TestSessionStoreTest < ActiveSupport::TestCase
    include ActionMCP::TestHelper

    def setup
      # Store original configuration
      @original_server_session_store_type = ActionMCP.configuration.server_session_store_type

      # Override configuration to use test session stores
      ActionMCP.configuration.instance_variable_set(:@server_session_store_type, :test)

      # Clear any cached session store so it gets recreated with the new configuration
      ActionMCP::Server.instance_variable_set(:@session_store, nil)
      ActionMCP::Server.instance_variable_set(:@session_store_type, nil)

      # Get the server's session store (will be created as TestSessionStore due to config override)
      @server_store = ActionMCP::Server.session_store
    end

    def teardown
      ActionMCP::Server.instance_variable_set(:@session_store, nil)
      ActionMCP::Server.instance_variable_set(:@session_store_type, nil)

      # Restore original configuration
      ActionMCP.configuration.instance_variable_set(:@server_session_store_type, @original_server_session_store_type)
    end

    test "server test store tracks session creation" do
      # Create a session
      @server_store.create_session("test-123", status: "initialized")

      # Use TestHelper assertions
      assert_session_created "test-123"
      assert_session_not_created "other-session"
      assert_session_operation_count 1, :create
    end

    test "server test store tracks all operations" do
      # Create, load, save, delete
      session = @server_store.create_session("test-456")
      @server_store.load_session("test-456")
      session.status = "active"
      @server_store.save_session(session)
      @server_store.delete_session("test-456")

      assert_session_created "test-456"
      assert_session_loaded "test-456"
      assert_session_saved "test-456"
      assert_session_deleted "test-456"
      assert_session_operation_count 4
    end

    test "test stores can be reset" do
      # Perform some operations
      @server_store.create_session("reset-1")
      @server_store.create_session("reset-2")

      assert_session_operation_count 2

      # Reset tracking
      @server_store.reset_tracking!

      assert_session_operation_count 0
    end

    test "test store operation details are tracked" do
      # Create session with specific attributes
      @server_store.create_session("detail-test", {
                                     status: "active",
                                     role: "client"
                                   })

      # Check the operation details
      operation = @server_store.operations.first
      assert_equal :create, operation[:type]
      assert_equal "detail-test", operation[:session_id]
      assert_equal "active", operation[:attributes][:status]
      assert_equal "client", operation[:attributes][:role]
    end

    test "server test store tracks cleanup operations" do
      # Create old and new sessions
      old_session = @server_store.create_session("old")
      old_session.updated_at = 2.days.ago

      @server_store.create_session("new")

      # Cleanup old sessions
      count = @server_store.cleanup_expired_sessions(older_than: 1.day.ago)

      assert_equal 1, count
      assert_session_operation_count 1, :cleanup

      # Check cleanup operation details
      cleanup_op = @server_store.operations.find { |op| op[:type] == :cleanup }
      assert_equal 1, cleanup_op[:count]
      assert cleanup_op[:older_than] < 1.day.ago
    end
  end
end
