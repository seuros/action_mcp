# frozen_string_literal: true

require "securerandom"
require "concurrent/map"
require "concurrent/array"
require "concurrent/executor/thread_pool_executor"

module ActionMCP
  module Server
    # Mock SolidCable::PubSub for testing
    class MockSolidCablePubSub
      attr_reader :subscriptions, :messages

      def initialize(options = {})
        @options = options
        @subscriptions = Concurrent::Map.new
        @messages = Concurrent::Array.new
      end

      def subscribe(channel, &block)
        @subscriptions[channel] ||= Concurrent::Array.new
        @subscriptions[channel] << block
      end

      def unsubscribe(channel)
        @subscriptions.delete(channel)
      end

      def broadcast(channel, message)
        @messages << { channel: channel, message: message }
        callbacks = @subscriptions[channel] || []
        callbacks.each { |callback| callback.call(message) }
      end
    end

    # Adapter for SolidCable PubSub
    class SolidCableAdapter
      # Thread pool configuration
      DEFAULT_MIN_THREADS = 5
      DEFAULT_MAX_THREADS = 10
      DEFAULT_MAX_QUEUE = 100
      DEFAULT_THREAD_TIMEOUT = 60  # seconds

      def initialize(options = {})
        @options = options
        @subscriptions = Concurrent::Map.new
        @channels = Concurrent::Map.new
        @channel_subscribed = Concurrent::Map.new  # Track channel subscription status

        # Initialize thread pool for callbacks
        pool_options = {
          min_threads: options["min_threads"] || DEFAULT_MIN_THREADS,
          max_threads: options["max_threads"] || DEFAULT_MAX_THREADS,
          max_queue: options["max_queue"] || DEFAULT_MAX_QUEUE,
          fallback_policy: :caller_runs, # Execute in the caller's thread if queue is full
          idletime: DEFAULT_THREAD_TIMEOUT
        }
        @thread_pool = Concurrent::ThreadPoolExecutor.new(pool_options)

        # Configure SolidCable with options from mcp.yml
        # The main option we care about is polling_interval
        pubsub_options = {}

        if @options["polling_interval"]
          # Convert from ActiveSupport::Duration if needed (e.g., "0.1.seconds")
          interval = @options["polling_interval"]
          interval = interval.to_f if interval.respond_to?(:to_f)
          pubsub_options[:polling_interval] = interval
        end

        # If there's a connects_to option, pass it along
        if @options["connects_to"]
          pubsub_options[:connects_to] = @options["connects_to"]
        end

        # Use mock version for testing or real version in production
        if defined?(SolidCable) && !testing?
          @solid_cable_pubsub = SolidCable::PubSub.new(pubsub_options)
        else
          @solid_cable_pubsub = MockSolidCablePubSub.new(pubsub_options)
        end
      end

      # Subscribe to a channel
      # @param channel [String] The channel name
      # @param message_callback [Proc] Callback for received messages
      # @param success_callback [Proc] Callback for successful subscription
      # @return [String] Subscription ID
      def subscribe(channel, message_callback, success_callback = nil)
        subscription_id = SecureRandom.uuid

        @subscriptions[subscription_id] = {
          channel: channel,
          message_callback: message_callback
        }

        @channels[channel] ||= Concurrent::Array.new
        @channels[channel] << subscription_id

        # Subscribe to SolidCable only if we haven't already subscribed to this channel
        unless subscribed_to_solid_cable?(channel)
          @solid_cable_pubsub.subscribe(channel) do |message|
            dispatch_message(channel, message)
          end
          @channel_subscribed[channel] = true
        end

        log_subscription_event(channel, "Subscribed", subscription_id)
        success_callback&.call

        subscription_id
      end

      # Unsubscribe from a channel
      # @param channel [String] The channel name
      # @param callback [Proc] Optional callback for unsubscribe completion
      def unsubscribe(channel, callback = nil)
        # Remove our subscriptions
        subscription_ids = @channels[channel] || []
        subscription_ids.each do |subscription_id|
          @subscriptions.delete(subscription_id)
        end

        @channels.delete(channel)

        # Only unsubscribe from SolidCable if we're actually subscribed
        if subscribed_to_solid_cable?(channel)
          @solid_cable_pubsub.unsubscribe(channel)
          @channel_subscribed.delete(channel)
        end

        log_subscription_event(channel, "Unsubscribed")
        callback&.call
      end

      # Broadcast a message to a channel
      # @param channel [String] The channel name
      # @param message [String] The message to broadcast
      def broadcast(channel, message)
        @solid_cable_pubsub.broadcast(channel, message)
        log_broadcast_event(channel, message)
      end

      # Check if a channel has subscribers
      # @param channel [String] The channel name
      # @return [Boolean] True if channel has subscribers
      def has_subscribers?(channel)
        subscribers = @channels[channel]
        return false unless subscribers
        !subscribers.empty?
      end

      # Check if we're already subscribed to a channel
      # @param channel [String] The channel name
      # @return [Boolean] True if we're already subscribed
      def subscribed_to?(channel)
        channel_subs = @channels[channel]
        return false if channel_subs.nil?
        !channel_subs.empty?
      end

      # Shut down the thread pool gracefully
      def shutdown
        @thread_pool.shutdown
        @thread_pool.wait_for_termination(5) # Wait up to 5 seconds for tasks to complete
      end

      private

      # Check if we're in a testing environment
      def testing?
        defined?(Minitest) || ENV["RAILS_ENV"] == "test"
      end

      # Check if we're already subscribed to this channel in SolidCable
      def subscribed_to_solid_cable?(channel)
        @channel_subscribed[channel] == true
      end

      def dispatch_message(channel, message)
        subscription_ids = @channels[channel] || []

        subscription_ids.each do |subscription_id|
          subscription = @subscriptions[subscription_id]
          next unless subscription && subscription[:message_callback]

          @thread_pool.post do
            begin
              subscription[:message_callback].call(message)
            rescue StandardError => e
              log_error("Error in message callback: #{e.message}\n#{e.backtrace.join("\n")}")
            end
          end
        end
      end

      def log_subscription_event(channel, action, subscription_id = nil)
        return unless defined?(Rails) && Rails.respond_to?(:logger)

        message = "SolidCableAdapter: #{action} channel=#{channel}"
        message += " subscription_id=#{subscription_id}" if subscription_id

        Rails.logger.debug(message)
      end

      def log_broadcast_event(channel, message)
        return unless defined?(Rails) && Rails.respond_to?(:logger)

        # Truncate the message for logging
        truncated_message = message.to_s[0..100]
        truncated_message += "..." if message.to_s.length > 100

        Rails.logger.debug("SolidCableAdapter: Broadcasting to channel=#{channel} message=#{truncated_message}")
      end

      def log_error(message)
        return unless defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.error("SolidCableAdapter: #{message}")
      end
    end
  end
end
