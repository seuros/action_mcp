# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class SimplePubSubTest < ActiveSupport::TestCase
      def setup
        @pubsub = SimplePubSub.new
        @received_messages = []
        @callback = ->(message) { @received_messages << message }
      end

      def test_subscribe_returns_subscription_id
        subscription_id = @pubsub.subscribe("test-channel", @callback)
        assert_kind_of String, subscription_id
        assert_match(/\A[0-9a-f-]+\z/, subscription_id, "Expected subscription_id to be a UUID")
      end

      def test_subscribed_to_returns_correct_status
        assert_equal false, @pubsub.subscribed_to?("test-channel")

        @pubsub.subscribe("test-channel", @callback)
        assert_equal true, @pubsub.subscribed_to?("test-channel")

        @pubsub.unsubscribe("test-channel")
        assert_equal false, @pubsub.subscribed_to?("test-channel")
      end

      def test_subscribe_calls_success_callback
        success_called = false
        success_callback = -> { success_called = true }

        @pubsub.subscribe("test-channel", @callback, success_callback)

        assert success_called, "Success callback was not called"
      end

      def test_broadcast_delivers_message_to_subscribers
        @pubsub.subscribe("test-channel", @callback)

        @pubsub.broadcast("test-channel", "test-message")

        assert wait_for_condition { @received_messages.include?("test-message") }
      end

      def test_broadcast_to_multiple_subscribers
        callbacks = []
        received = []

        3.times do |i|
          received[i] = []
          callbacks[i] = ->(message) { received[i] << message }
          @pubsub.subscribe("test-channel", callbacks[i])
        end

        @pubsub.broadcast("test-channel", "multi-message")

        3.times do |i|
          assert wait_for_condition { received[i].include?("multi-message") }
        end
      end

      def test_unsubscribe_prevents_message_delivery
        subscription_id = @pubsub.subscribe("test-channel", @callback)

        # Unsubscribe before broadcasting
        @pubsub.unsubscribe("test-channel")
        @pubsub.broadcast("test-channel", "test-message")

        # The callback should not be invoked
        sleep 0.1  # Give potential message delivery time to occur
        assert_empty @received_messages
      end

      def test_messages_only_delivered_to_correct_channel
        channel1_messages = []
        channel2_messages = []

        @pubsub.subscribe("channel-1", ->(message) { channel1_messages << message })
        @pubsub.subscribe("channel-2", ->(message) { channel2_messages << message })

        @pubsub.broadcast("channel-1", "message-1")
        @pubsub.broadcast("channel-2", "message-2")

        assert wait_for_condition { channel1_messages.include?("message-1") }
        assert wait_for_condition { channel2_messages.include?("message-2") }

        refute_includes channel1_messages, "message-2"
        refute_includes channel2_messages, "message-1"
      end

      def test_has_subscribers_returns_correct_status
        assert_equal false, @pubsub.has_subscribers?("test-channel")

        @pubsub.subscribe("test-channel", @callback)
        assert_equal true, @pubsub.has_subscribers?("test-channel")

        @pubsub.unsubscribe("test-channel")
        assert_equal false, @pubsub.has_subscribers?("test-channel")
      end
    end
  end
end
