# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class SolidCableAdapterTest < ActiveSupport::TestCase
      def setup
        # Create the adapter with mock SolidCable implementation
        @adapter = SolidCableAdapter.new("polling_interval" => 0.1)
        @received_messages = []
        @callback = ->(message) { @received_messages << message }
      end

      def teardown
        # No cleanup needed with mock implementation
      end

      def test_subscribe_returns_subscription_id
        subscription_id = @adapter.subscribe("test-channel", @callback)
        assert_kind_of String, subscription_id
        assert_match(/\A[0-9a-f-]+\z/, subscription_id, "Expected subscription_id to be a UUID")
      end

      def test_subscribe_calls_success_callback
        success_called = false
        success_callback = -> { success_called = true }

        @adapter.subscribe("test-channel", @callback, success_callback)

        assert success_called, "Success callback was not called"
      end

      def test_broadcast_delivers_message_to_subscribers
        @adapter.subscribe("test-channel", @callback)

        @adapter.broadcast("test-channel", "test-message")

        assert wait_for_condition(2) { @received_messages.include?("test-message") }
      end

      def test_broadcast_to_multiple_subscribers
        callbacks = []
        received = []

        3.times do |i|
          received[i] = []
          callbacks[i] = ->(message) { received[i] << message }
          @adapter.subscribe("test-channel", callbacks[i])
        end

        @adapter.broadcast("test-channel", "multi-message")

        3.times do |i|
          assert wait_for_condition(2) { received[i].include?("multi-message") }
        end
      end

      def test_unsubscribe_prevents_message_delivery
        @adapter.subscribe("test-channel", @callback)

        # Unsubscribe before broadcasting
        @adapter.unsubscribe("test-channel")
        @adapter.broadcast("test-channel", "test-message")

        # The callback should not be invoked
        sleep 0.5 # Give more time for SolidCable to poll
        assert_empty @received_messages
      end

      def test_messages_only_delivered_to_correct_channel
        channel1_messages = []
        channel2_messages = []

        @adapter.subscribe("channel-1", ->(message) { channel1_messages << message })
        @adapter.subscribe("channel-2", ->(message) { channel2_messages << message })

        @adapter.broadcast("channel-1", "message-1")
        @adapter.broadcast("channel-2", "message-2")

        assert wait_for_condition(2) { channel1_messages.include?("message-1") }
        assert wait_for_condition(2) { channel2_messages.include?("message-2") }

        refute_includes channel1_messages, "message-2"
        refute_includes channel2_messages, "message-1"
      end

      def test_has_subscribers_returns_correct_status
        assert_equal false, @adapter.has_subscribers?("test-channel")

        @adapter.subscribe("test-channel", @callback)
        assert_equal true, @adapter.has_subscribers?("test-channel")

        @adapter.unsubscribe("test-channel")
        assert_equal false, @adapter.has_subscribers?("test-channel")
      end

      def test_subscribed_to_returns_correct_status
        assert_equal false, @adapter.subscribed_to?("test-channel")

        @adapter.subscribe("test-channel", @callback)
        assert_equal true, @adapter.subscribed_to?("test-channel")

        @adapter.unsubscribe("test-channel")
        assert_equal false, @adapter.subscribed_to?("test-channel")
      end

      def test_optimizes_subscriptions_to_solid_cable
        # Get the mock pub/sub instance to test if it received a subscription
        mock_pubsub = @adapter.instance_variable_get(:@solid_cable_pubsub)

        # First subscription should register with the underlying adapter
        @adapter.subscribe("optimize-channel", @callback)
        assert_equal 1, mock_pubsub.subscriptions["optimize-channel"]&.size || 0

        # Second subscription to same channel should reuse existing subscription
        @adapter.subscribe("optimize-channel", ->(_msg) { puts "another callback" })
        assert_equal 1, mock_pubsub.subscriptions["optimize-channel"]&.size || 0

        # Different channel should get a new subscription
        @adapter.subscribe("different-channel", @callback)
        assert_equal 1, mock_pubsub.subscriptions["different-channel"]&.size || 0
      end

      # No private methods needed with mock implementation
    end
  end
end
