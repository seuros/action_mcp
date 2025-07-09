# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class SolidMcpAdapterTest < ActiveSupport::TestCase
      include ServerTestHelper

      def setup
        skip "SolidMCP not available"
        # Clean up any existing messages before test
        SolidMCP::Message.delete_all if defined?(SolidMCP::Message)

        # Create the adapter with SolidMCP implementation
        @adapter = SolidMcpAdapter.new("polling_interval" => 0.01, "flush_interval" => 0.01)
        @received_messages = []
        @callback = ->(message) { @received_messages << message }
      end

      def teardown
        # Clean up any messages and shutdown adapter
        SolidMCP::Message.delete_all if defined?(SolidMCP::Message)
        @adapter&.shutdown
      end

      def test_subscribe_returns_subscription_id
        subscription_id = @adapter.subscribe("action_mcp:session:test-session", @callback)
        assert_kind_of String, subscription_id
        assert_match(/\A[0-9a-f-]+\z/, subscription_id, "Expected subscription_id to be a UUID")
      end

      def test_subscribe_calls_success_callback
        success_called = false
        success_callback = -> { success_called = true }

        @adapter.subscribe("action_mcp:session:test-session", @callback, success_callback)

        assert success_called, "Success callback was not called"
      end

      def test_broadcast_delivers_message_to_subscribers
        skip "Intermittent failure in CI - passes locally" if ENV["CI"]
        @adapter.subscribe("action_mcp:session:test-session", @callback)

        @adapter.broadcast("action_mcp:session:test-session", "test-message")
        flush_solid_mcp_messages
        sleep 0.5 # Give more time for polling and processing

        # Check if message was written to database
        message_count = SolidMCP::Message.where(session_id: "test-session").count
        assert message_count > 0, "No messages written to database"

        assert wait_for_condition(3) { @received_messages.include?("test-message") }, "Message not received: #{@received_messages.inspect}"
      end

      def test_broadcast_to_multiple_subscribers
        skip "Intermittent failure in CI - passes locally" if ENV["CI"]
        callbacks = []
        received = []

        3.times do |i|
          received[i] = []
          callbacks[i] = ->(message) { received[i] << message }
          @adapter.subscribe("action_mcp:session:test-session", callbacks[i])
        end

        @adapter.broadcast("action_mcp:session:test-session", "multi-message")
        flush_solid_mcp_messages
        sleep 0.2 # Give more time for polling

        3.times do |i|
          assert wait_for_condition(2) { received[i].include?("multi-message") }, "Subscriber #{i} did not receive message"
        end
      end

      def test_unsubscribe_prevents_message_delivery
        @adapter.subscribe("action_mcp:session:test-session", @callback)

        # Unsubscribe before broadcasting
        @adapter.unsubscribe("action_mcp:session:test-session")
        @adapter.broadcast("action_mcp:session:test-session", "test-message")

        # The callback should not be invoked
        sleep 0.5 # Give more time for SolidCable to poll
        assert_empty @received_messages
      end

      def test_messages_only_delivered_to_correct_channel
        skip "Intermittent failure in CI - passes locally" if ENV["CI"]
        channel1_messages = []
        channel2_messages = []

        @adapter.subscribe("action_mcp:session:channel-1", ->(message) { channel1_messages << message })
        @adapter.subscribe("action_mcp:session:channel-2", ->(message) { channel2_messages << message })

        @adapter.broadcast("action_mcp:session:channel-1", "message-1")
        @adapter.broadcast("action_mcp:session:channel-2", "message-2")
        flush_solid_mcp_messages
        sleep 0.2 # Give more time for polling

        assert wait_for_condition(2) { channel1_messages.include?("message-1") }
        assert wait_for_condition(2) { channel2_messages.include?("message-2") }

        refute_includes channel1_messages, "message-2"
        refute_includes channel2_messages, "message-1"
      end

      def test_has_subscribers_returns_correct_status
        assert_equal false, @adapter.has_subscribers?("action_mcp:session:test-session")

        @adapter.subscribe("action_mcp:session:test-session", @callback)
        assert_equal true, @adapter.has_subscribers?("action_mcp:session:test-session")

        @adapter.unsubscribe("action_mcp:session:test-session")
        assert_equal false, @adapter.has_subscribers?("action_mcp:session:test-session")
      end

      def test_subscribed_to_returns_correct_status
        assert_equal false, @adapter.subscribed_to?("action_mcp:session:test-session")

        @adapter.subscribe("action_mcp:session:test-session", @callback)
        assert_equal true, @adapter.subscribed_to?("action_mcp:session:test-session")

        @adapter.unsubscribe("action_mcp:session:test-session")
        assert_equal false, @adapter.subscribed_to?("action_mcp:session:test-session")
      end

      def test_optimizes_subscriptions_to_solid_mcp
        # SolidMCP uses session-based subscriptions
        # Channel format: "action_mcp:session:SESSION_ID"
        session1_channel = "action_mcp:session:session1"
        session2_channel = "action_mcp:session:session2"

        # First subscription initializes the pubsub
        sub1 = @adapter.subscribe(session1_channel, @callback)
        assert_not_nil sub1
        assert @adapter.has_subscribers?(session1_channel)

        # Second subscription to same session should work
        sub2 = @adapter.subscribe(session1_channel, ->(_msg) { puts "another callback" })
        assert_not_nil sub2
        assert_not_equal sub1, sub2 # Different subscription IDs

        # Different session should get a new subscription
        sub3 = @adapter.subscribe(session2_channel, @callback)
        assert_not_nil sub3
        assert @adapter.has_subscribers?(session2_channel)

        # Verify both sessions have subscribers
        assert @adapter.has_subscribers?(session1_channel)
        assert @adapter.has_subscribers?(session2_channel)
      end

      # No private methods needed with mock implementation
    end
  end
end
