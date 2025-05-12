# frozen_string_literal: true

require "securerandom"
require "concurrent/map"
require "concurrent/array"
require "concurrent/executor/thread_pool_executor"

module ActionMCP
  module Server
    # Simple in-memory PubSub implementation for testing and development
    class SimplePubSub
      # Thread pool configuration
      DEFAULT_MIN_THREADS = 5
      DEFAULT_MAX_THREADS = 10
      DEFAULT_MAX_QUEUE = 100
      DEFAULT_THREAD_TIMEOUT = 60  # seconds

      def initialize(options = {})
        @subscriptions = Concurrent::Map.new
        @channels = Concurrent::Map.new

        # Initialize thread pool for callbacks
        pool_options = {
          min_threads: options["min_threads"] || DEFAULT_MIN_THREADS,
          max_threads: options["max_threads"] || DEFAULT_MAX_THREADS,
          max_queue: options["max_queue"] || DEFAULT_MAX_QUEUE,
          fallback_policy: :caller_runs, # Execute in the caller's thread if queue is full
          idletime: DEFAULT_THREAD_TIMEOUT
        }
        @thread_pool = Concurrent::ThreadPoolExecutor.new(pool_options)
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

        log_subscription_event(channel, "Unsubscribed")
        callback&.call
      end

      # Broadcast a message to a channel
      # @param channel [String] The channel name
      # @param message [String] The message to broadcast
      def broadcast(channel, message)
        subscription_ids = @channels[channel] || []
        return if subscription_ids.empty?

        log_broadcast_event(channel, message)

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

      # Check if a channel has subscribers
      # @param channel [String] The channel name
      # @return [Boolean] True if channel has subscribers
      def has_subscribers?(channel)
        subscribers = @channels[channel]
        return false unless subscribers
        !subscribers.empty?
      end

      # Shut down the thread pool gracefully
      def shutdown
        @thread_pool.shutdown
        @thread_pool.wait_for_termination(5) # Wait up to 5 seconds for tasks to complete
      end

      private

      def log_subscription_event(channel, action, subscription_id = nil)
        return unless defined?(Rails) && Rails.respond_to?(:logger)

        message = "SimplePubSub: #{action} channel=#{channel}"
        message += " subscription_id=#{subscription_id}" if subscription_id

        Rails.logger.debug(message)
      end

      def log_broadcast_event(channel, message)
        return unless defined?(Rails) && Rails.respond_to?(:logger)

        # Truncate the message for logging
        truncated_message = message.to_s[0..100]
        truncated_message += "..." if message.to_s.length > 100

        Rails.logger.debug("SimplePubSub: Broadcasting to channel=#{channel} message=#{truncated_message}")
      end

      def log_error(message)
        return unless defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.error("SimplePubSub: #{message}")
      end
    end
  end
end
