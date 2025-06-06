require "test_helper"

module ActionMCP
  module Server
    class SessionStoreTest < ActiveSupport::TestCase
      def setup
        @volatile_store = VolatileSessionStore.new
        @ar_store = ActiveRecordSessionStore.new
      end

      test "volatile store creates session with default attributes" do
        session = @volatile_store.create_session

        assert_not_nil session
        assert_not_nil session.id
        assert_equal "pre_initialize", session.status
        assert_equal false, session.initialized
        assert_equal "server", session.role
        assert_equal 0, session.messages_count
      end

      test "volatile store creates session with custom id and attributes" do
        session = @volatile_store.create_session("custom-id", status: "initialized", initialized: true)

        assert_equal "custom-id", session.id
        assert_equal "initialized", session.status
        assert_equal true, session.initialized
      end

      test "volatile store loads existing session" do
        session = @volatile_store.create_session("test-id")
        loaded = @volatile_store.load_session("test-id")

        assert_equal session, loaded
        assert_equal session.id, loaded.id
      end

      test "volatile store returns nil for non-existent session" do
        assert_nil @volatile_store.load_session("non-existent")
      end

      test "volatile store saves session updates" do
        session = @volatile_store.create_session("test-id", status: "pre_initialize")
        session.status = "initialized"
        session.initialized = true
        @volatile_store.save_session(session)

        loaded = @volatile_store.load_session("test-id")
        assert_equal "initialized", loaded.status
        assert_equal true, loaded.initialized
      end

      test "volatile store deletes session" do
        session = @volatile_store.create_session("test-id")
        assert @volatile_store.session_exists?("test-id")

        @volatile_store.delete_session("test-id")
        assert_not @volatile_store.session_exists?("test-id")
        assert_nil @volatile_store.load_session("test-id")
      end

      test "volatile store finds sessions by criteria" do
        @volatile_store.create_session("s1", status: "initialized", role: "server")
        @volatile_store.create_session("s2", status: "closed", role: "server")
        @volatile_store.create_session("s3", status: "initialized", role: "client")

        initialized = @volatile_store.find_sessions(status: "initialized")
        assert_equal 2, initialized.size

        servers = @volatile_store.find_sessions(role: "server")
        assert_equal 2, servers.size

        initialized_servers = @volatile_store.find_sessions(status: "initialized", role: "server")
        assert_equal 1, initialized_servers.size
      end

      test "volatile store cleans up expired sessions" do
        # Create old session
        old_session = @volatile_store.create_session("old")
        old_session.updated_at = 2.days.ago

        # Create new session
        new_session = @volatile_store.create_session("new")

        # Ensure sessions exist before cleanup
        assert @volatile_store.session_exists?("old")
        assert @volatile_store.session_exists?("new")

        count = @volatile_store.cleanup_expired_sessions(older_than: 1.day.ago)
        assert_equal 1, count
        assert_nil @volatile_store.load_session("old")
        assert_not_nil @volatile_store.load_session("new")
      end

      test "memory session mimics ActiveRecord interface" do
        session = @volatile_store.create_session("test-id")

        # Test save methods
        assert session.save
        assert session.save!

        # Test update methods
        session.update(status: "initialized")
        assert_equal "initialized", session.status

        session.update!(initialized: true)
        assert_equal true, session.initialized

        # Test reload (no-op for memory)
        assert_equal session, session.reload
      end

      test "memory session handles messages" do
        session = @volatile_store.create_session("test-id")

        session.write("test message")
        assert_equal 1, session.messages_count

        session.read("response")
        assert_equal 2, session.messages_count
      end

      test "memory session handles SSE events" do
        session = @volatile_store.create_session("test-id")

        # Test increment counter
        count1 = session.increment_sse_counter!
        count2 = session.increment_sse_counter!
        assert_equal 1, count1
        assert_equal 2, count2

        # Test store event
        session.store_sse_event(1, { data: "test" })
        session.store_sse_event(2, { data: "test2" })

        # Test get events after
        events = session.get_sse_events_after(0)
        assert_equal 2, events.size

        events = session.get_sse_events_after(1)
        assert_equal 1, events.size
        assert_equal 2, events.first[:event_id]
      end

      test "memory session handles subscriptions" do
        session = @volatile_store.create_session("test-id")

        session.resource_subscribe("test://resource")
        session.resource_subscribe("test://resource") # duplicate
        session.resource_subscribe("test://resource2")

        assert_equal 2, session.subscriptions.size

        session.resource_unsubscribe("test://resource")
        assert_equal 1, session.subscriptions.size
      end

      test "memory session handles registries" do
        session = @volatile_store.create_session("test-id")

        # Initialize registries
        session.tool_registry = [ "calculate_sum" ]
        session.prompt_registry = [ "greeting" ]
        session.resource_registry = []

        # Should have the initial registries
        assert_includes session.tool_registry, "calculate_sum"
        assert_includes session.prompt_registry, "greeting"
      end

      test "ActiveRecord store delegates to ActiveRecord Session" do
        # Create via AR store
        session = @ar_store.create_session("ar-test", status: "initialized")

        assert_instance_of ActionMCP::Session, session
        assert_equal "ar-test", session.id
        assert_equal "initialized", session.status

        # Load via AR store
        loaded = @ar_store.load_session("ar-test")
        assert_equal session.id, loaded.id

        # Delete via AR store
        @ar_store.delete_session("ar-test")
        assert_nil @ar_store.load_session("ar-test")
      end

      test "SessionStoreFactory creates correct store type" do
        volatile = SessionStoreFactory.create(:volatile)
        assert_instance_of VolatileSessionStore, volatile

        ar = SessionStoreFactory.create(:active_record)
        assert_instance_of ActiveRecordSessionStore, ar

        # Default based on environment
        default = SessionStoreFactory.create
        if Rails.env.production?
          assert_instance_of ActiveRecordSessionStore, default
        else
          assert_instance_of VolatileSessionStore, default
        end
      end

      test "SessionStoreFactory raises on unknown type" do
        assert_raises(ArgumentError) do
          SessionStoreFactory.create(:unknown)
        end
      end
    end
  end
end
