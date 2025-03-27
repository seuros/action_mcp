# frozen_string_literal: true

require "concurrent/atomic/atomic_boolean"
require "concurrent/promise"

module ActionMCP
  # Listener class to subscribe to session messages via Action Cable adapter.
  # Used by controllers handling Server-Sent Events streams.
  class SSEListener
    attr_reader :session_key, :adapter

    delegate :session_key, :adapter, to: :@session

    # @param session [ActionMCP::Session]
    def initialize(session)
      @session = session
      @stopped = Concurrent::AtomicBoolean.new(false)
      @subscription_active = Concurrent::AtomicBoolean.new(false)
    end

    # Start listening using ActionCable's adapter
    # @yield [Hash] Yields parsed message received from the pub/sub channel
    # @return [Boolean] True if subscription was successful within timeout, false otherwise.
    def start(&callback)
      Rails.logger.debug "SSEListener: Starting for channel: #{session_key}"

      success_callback = lambda {
        Rails.logger.info "SSEListener: Successfully subscribed to channel: #{session_key}"
        @subscription_active.make_true
      }

      # Set up message callback
      message_callback = lambda { |raw_message|
        return if @stopped.true?

        begin
          # Try to parse the message if it's JSON
          message = MultiJson.load(raw_message)
          # Send the message to the callback
          # TODO: Add SSE event ID here if implementing resumability
          callback&.call(message)
        rescue StandardError => e
          Rails.logger.error "SSEListener: Error processing message: #{e.message}"
          # Still try to send the raw message as a fallback? Or ignore?
          # callback.call(raw_message) if callback
        end
      }

      # Subscribe using the ActionCable adapter
      adapter.subscribe(session_key, message_callback, success_callback)

      # Use a future with timeout to check subscription status
      subscription_future = Concurrent::Promises.future do
        sleep 0.1 while !@subscription_active.true? && !@stopped.true?
        @subscription_active.true?
      end

      # Wait up to 5 seconds for subscription to be established (increased timeout)
      begin
        subscription_result = subscription_future.value(5)
        subscription_result || @subscription_active.true?
      rescue Concurrent::TimeoutError
        Rails.logger.warn "SSEListener: Timed out waiting for subscription activation for #{session_key}"
        false
      end
    end

    # Stops the listener and attempts to unsubscribe.
    def stop
      return if @stopped.true? # Prevent multiple stops

      @stopped.make_true
      # Unsubscribe using the adapter
      # Note: ActionCable adapters might not have a direct 'unsubscribe' matching this pattern.
      # We rely on closing the connection and potentially session cleanup.
      # If using Redis adapter, explicit unsubscribe might be possible/needed.
      # For now, just log.
      Rails.logger.debug "SSEListener: Stopping listener for channel: #{session_key}"
      # If session cleanup is needed when listener stops, add it here or ensure it happens elsewhere.
      # Example: @session.close! if @session.role == 'server' # Be careful with side effects
    end
  end
end
