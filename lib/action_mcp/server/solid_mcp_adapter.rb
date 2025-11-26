# frozen_string_literal: true

require "securerandom"
require "concurrent/map"
require "concurrent/array"

module ActionMCP
  module Server
    # Adapter for SolidMCP PubSub - optimized for MCP's session-based messaging
    class SolidMcpAdapter
      def initialize(options = {})
        @options = options
        @subscriptions = Concurrent::Map.new
        @session_callbacks = Concurrent::Map.new
        @pubsub = nil
      end

      # Subscribe to a session's messages
      # @param channel [String] The channel name (format: "action_mcp:session:SESSION_ID")
      # @param message_callback [Proc] Callback for received messages
      # @param success_callback [Proc] Callback for successful subscription
      # @return [String] Subscription ID
      def subscribe(channel, message_callback, success_callback = nil)
        subscription_id = SecureRandom.uuid_v7
        session_id = extract_session_id(channel)

        @subscriptions[subscription_id] = {
          channel: channel,
          session_id: session_id,
          message_callback: message_callback
        }

        # Initialize callback array for this session if needed
        @session_callbacks[session_id] ||= Concurrent::Array.new

        # Only subscribe to SolidMCP once per session
        if @session_callbacks[session_id].empty?
          ensure_pubsub.subscribe(session_id) do |message|
            # Message from SolidMCP includes event_type, data, and id
            # Deliver to all callbacks for this session
            @subscriptions.each_value do |subscription|
              next unless subscription[:session_id] == session_id && subscription[:message_callback]

              begin
                subscription[:message_callback].call(message[:data])
              rescue StandardError => e
                log_error("Error in message callback: #{e.message}")
              end
            end
          end
        end

        # Track that we have a callback for this session
        @session_callbacks[session_id] << subscription_id

        log_subscription_event(channel, "Subscribed", subscription_id)
        success_callback&.call

        subscription_id
      end

      # Unsubscribe from a channel
      # @param channel [String] The channel name
      # @param callback [Proc] Optional callback for unsubscribe completion
      def unsubscribe(channel, callback = nil)
        session_id = extract_session_id(channel)

        # Remove subscriptions for this channel
        removed_ids = []
        @subscriptions.each do |id, sub|
          if sub[:channel] == channel
            @subscriptions.delete(id)
            removed_ids << id
          end
        end

        # Remove from session callbacks
        removed_ids.each do |id|
          @session_callbacks[session_id]&.delete(id)
        end

        # Only unsubscribe from SolidMCP if no more callbacks for this session
        if @session_callbacks[session_id] && @session_callbacks[session_id].empty?
          ensure_pubsub.unsubscribe(session_id)
          @session_callbacks.delete(session_id)
        end

        log_subscription_event(channel, "Unsubscribed")
        callback&.call
      end

      # Broadcast a message to a channel
      # @param channel [String] The channel name
      # @param message [String] The message to broadcast
      def broadcast(channel, message)
        session_id = extract_session_id(channel)

        # Parse the message to extract event type if it's JSON-RPC
        event_type = extract_event_type(message)

        ensure_pubsub.broadcast(session_id, event_type, message)
        log_broadcast_event(channel, message)
      end

      # Check if a channel has subscribers
      # @param channel [String] The channel name
      # @return [Boolean] True if channel has subscribers
      def has_subscribers?(channel)
        @subscriptions.values.any? { |sub| sub[:channel] == channel }
      end

      # Check if we're subscribed to a channel
      # @param channel [String] The channel name
      # @return [Boolean] True if we're subscribed
      def subscribed_to?(channel)
        has_subscribers?(channel)
      end

      # Shut down the adapter gracefully
      def shutdown
        @pubsub&.shutdown
        @pubsub = nil
      end

      private

      def ensure_pubsub
        @ensure_pubsub ||= SolidMCP::PubSub.new(@options)
      end

      def extract_session_id(channel)
        # Channel format: "action_mcp:session:SESSION_ID"
        channel.split(":").last
      end

      def extract_event_type(message)
        # Try to parse as JSON to get the method (event type)
        data = JSON.parse(message)
        data["method"] || "message"
      rescue JSON::ParserError
        "message"
      end

      def log_subscription_event(channel, action, subscription_id = nil)
        return unless defined?(Rails) && Rails.respond_to?(:logger)

        message = "SolidMcpAdapter: #{action} channel=#{channel}"
        message += " subscription_id=#{subscription_id}" if subscription_id

        Rails.logger.debug(message)
      end

      def log_broadcast_event(channel, message)
        return unless defined?(Rails) && Rails.respond_to?(:logger)

        # Truncate the message for logging
        truncated_message = message.to_s[0..100]
        truncated_message += "..." if message.to_s.length > 100

        Rails.logger.debug("SolidMcpAdapter: Broadcasting to channel=#{channel} message=#{truncated_message}")
      end

      def log_error(message)
        return unless defined?(Rails) && Rails.respond_to?(:logger)

        Rails.logger.error("SolidMcpAdapter: #{message}")
      end
    end
  end
end
