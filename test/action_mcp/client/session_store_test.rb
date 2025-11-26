# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Client
    class SessionStoreTest < ActiveSupport::TestCase
      fixtures :action_mcp_sessions

      def setup
        @volatile_store = VolatileSessionStore.new
        @ar_store = ActiveRecordSessionStore.new
      end

      # Memory Store Tests
      test "memory store saves and loads session data" do
        session_data = {
          id: "test-123",
          protocol_version: "2025-06-18",
          client_info: { name: "TestClient", version: "1.0" },
          server_info: { name: "TestServer", version: "2.0" },
          last_event_id: 42
        }

        @volatile_store.save_session("test-123", session_data)
        loaded = @volatile_store.load_session("test-123")

        assert_equal session_data[:id], loaded[:id]
        assert_equal session_data[:protocol_version], loaded[:protocol_version]
        assert_equal session_data[:client_info], loaded[:client_info]
        assert_equal session_data[:server_info], loaded[:server_info]
        assert_equal session_data[:last_event_id], loaded[:last_event_id]
      end

      test "memory store returns nil for non-existent session" do
        assert_nil @volatile_store.load_session("non-existent")
      end

      test "memory store deletes session" do
        @volatile_store.save_session("test-123", { id: "test-123" })
        assert @volatile_store.session_exists?("test-123")

        @volatile_store.delete_session("test-123")
        assert_not @volatile_store.session_exists?("test-123")
        assert_nil @volatile_store.load_session("test-123")
      end

      test "memory store duplicates session data on save" do
        original_data = { id: "test-123", data: "original" }
        @volatile_store.save_session("test-123", original_data)

        # Modify original data
        original_data[:data] = "modified"

        # Load should return original value
        loaded = @volatile_store.load_session("test-123")
        assert_equal "original", loaded[:data]
      end

      test "memory store updates specific session attributes" do
        @volatile_store.save_session("test-123", {
                                       id: "test-123",
                                       protocol_version: "2025-06-18",
                                       last_event_id: 10
                                     })

        updated = @volatile_store.update_session("test-123", { last_event_id: 20 })

        assert_equal "test-123", updated[:id]
        assert_equal "2025-06-18", updated[:protocol_version]
        assert_equal 20, updated[:last_event_id]
      end

      test "memory store returns nil when updating non-existent session" do
        result = @volatile_store.update_session("non-existent", { last_event_id: 20 })
        assert_nil result
      end

      test "memory store clears all sessions" do
        @volatile_store.save_session("s1", { id: "s1" })
        @volatile_store.save_session("s2", { id: "s2" })
        assert_equal 2, @volatile_store.session_count

        @volatile_store.clear_all
        assert_equal 0, @volatile_store.session_count
        assert_nil @volatile_store.load_session("s1")
        assert_nil @volatile_store.load_session("s2")
      end

      test "memory store is thread-safe" do
        threads = []
        session_ids = []

        # Create multiple threads that save sessions concurrently
        10.times do |i|
          threads << Thread.new do
            session_id = "thread-#{i}"
            session_ids << session_id
            100.times do |j|
              @volatile_store.save_session(session_id, {
                                             id: session_id,
                                             counter: j
                                           })
            end
          end
        end

        threads.each(&:join)

        # Verify all sessions exist with final values
        session_ids.each do |session_id|
          session = @volatile_store.load_session(session_id)
          assert_not_nil session
          assert_equal 99, session[:counter]
        end
      end

      # ActiveRecord Store Tests
      test "ActiveRecord store saves and loads session via database" do
        session_data = {
          id: "ar-test-123",
          protocol_version: "2025-06-18",
          client_info: { name: "TestClient", version: "1.0" },
          server_info: { name: "TestServer", version: "2.0" },
          client_capabilities: { tools: {}, prompts: {} },
          server_capabilities: { tools: {}, prompts: {} }
        }

        @ar_store.save_session("ar-test-123", session_data)
        loaded = @ar_store.load_session("ar-test-123")

        assert_equal session_data[:id], loaded[:id]
        assert_equal session_data[:protocol_version], loaded[:protocol_version]
        assert_equal session_data[:client_info].stringify_keys, loaded[:client_info]
        # Server info is automatically set by the Session model
        assert_not_nil loaded[:server_info]
        assert_equal session_data[:client_capabilities].deep_stringify_keys, loaded[:client_capabilities]
        assert_equal session_data[:server_capabilities].deep_stringify_keys, loaded[:server_capabilities]
      end

      test "ActiveRecord store returns nil for non-existent session" do
        assert_nil @ar_store.load_session("ar-non-existent")
      end

      test "ActiveRecord store deletes session from database" do
        @ar_store.save_session("ar-delete-test", {
                                 id: "ar-delete-test",
                                 protocol_version: "2025-06-18"
                               })
        assert @ar_store.session_exists?("ar-delete-test")

        @ar_store.delete_session("ar-delete-test")
        assert_not @ar_store.session_exists?("ar-delete-test")
        assert_nil @ar_store.load_session("ar-delete-test")
      end

      test "ActiveRecord store updates existing session" do
        @ar_store.save_session("ar-update-test", {
                                 id: "ar-update-test",
                                 protocol_version: "2025-06-18",
                                 client_info: { name: "TestClient", version: "1.0" }
                               })

        @ar_store.save_session("ar-update-test", {
                                 id: "ar-update-test",
                                 protocol_version: "2025-06-18",
                                 client_info: { name: "TestClient", version: "2.0" }
                               })

        loaded = @ar_store.load_session("ar-update-test")
        assert_equal "2.0", loaded[:client_info]["version"]
      end

      test "ActiveRecord store updates specific attributes" do
        @ar_store.save_session("ar-partial-update", {
                                 id: "ar-partial-update",
                                 protocol_version: "2025-06-18",
                                 client_info: { name: "TestClient", version: "1.0" }
                               })

        updated = @ar_store.update_session("ar-partial-update", {
                                             client_info: { name: "TestClient", version: "2.0" }
                                           })

        assert_equal "ar-partial-update", updated[:id]
        assert_equal "2025-06-18", updated[:protocol_version]
        assert_equal "TestClient", updated[:client_info]["name"]
        assert_equal "2.0", updated[:client_info]["version"]
      end

      test "ActiveRecord store cleans up expired sessions" do
        # Create old session directly in DB
        old_session = action_mcp_sessions(:test_session)
        old_session.update!(
          id: "ar-old-session",
          protocol_version: "2025-06-18",
          updated_at: 2.days.ago
        )

        # Create new session
        @ar_store.save_session("ar-new-session", {
                                 id: "ar-new-session",
                                 protocol_version: "2025-06-18"
                               })

        count = @ar_store.cleanup_expired_sessions(older_than: 1.day.ago)
        assert_equal 1, count
        assert_nil @ar_store.load_session("ar-old-session")
        assert_not_nil @ar_store.load_session("ar-new-session")
      end

      # Factory Tests
      test "SessionStoreFactory creates memory store" do
        store = SessionStoreFactory.create(:memory)
        assert_instance_of VolatileSessionStore, store
      end

      test "SessionStoreFactory creates ActiveRecord store" do
        store = SessionStoreFactory.create(:active_record)
        assert_instance_of ActiveRecordSessionStore, store
      end

      test "SessionStoreFactory uses default based on configuration" do
        store = SessionStoreFactory.create
        expected_type = ActionMCP.configuration.client_session_store_type
        if expected_type == :active_record
          assert_instance_of ActiveRecordSessionStore, store
        else
          assert_instance_of VolatileSessionStore, store
        end
      end

      test "SessionStoreFactory raises on unknown type" do
        assert_raises(ArgumentError) do
          SessionStoreFactory.create(:unknown)
        end
      end

      teardown do
        # Clean up any ActiveRecord sessions created during tests
        ActionMCP::Session.where("id LIKE ?", "ar-%").destroy_all
      end
    end
  end
end
