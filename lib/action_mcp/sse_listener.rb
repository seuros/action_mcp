# frozen_string_literal: true

require "concurrent/atomic/atomic_boolean"
require "concurrent/promise"

module ActionMCP
  # Listener class to subscribe to session messages via PubSub adapter.
  class SSEListener
    delegate :session_key, :adapter, to: :@session

    # @param session [ActionMCP::Session]
    def initialize(session)
      @session = session
      @stopped = Concurrent::AtomicBoolean.new
      @subscription_active = Concurrent::AtomicBoolean.new
    end

    # Start listening using PubSub adapter
    # @yield [Hash] Yields parsed message received from the pub/sub channel
    # @return [Boolean] True if subscription was successful within timeout, false otherwise.
    def start(&callback)
      Rails.logger.debug "SSEListener: Starting for channel: #{session_key}"

      success_callback = lambda {
        Rails.logger.info "SSEListener: Successfully subscribed to channel: #{session_key}"
        @subscription_active.make_true
      }

      message_callback = lambda { |raw_message|
        process_message(raw_message, callback)
      }

      # Subscribe using the PubSub adapter
      adapter.subscribe(session_key, message_callback, success_callback)

      wait_for_subscription
    end

    # Stops the listener
    def stop
      return if @stopped.true?

      @stopped.make_true
      Rails.logger.debug "SSEListener: Stopping listener for channel: #{session_key}"
    end

    private

    def process_message(raw_message, callback)
      return if @stopped.true?

      begin
        Rails.logger.debug "SSEListener: Received raw message of type: #{raw_message.class}"

        # Check if the message is a valid JSON string or has a message attribute
        if raw_message.is_a?(String) && valid_json_format?(raw_message)
          message = MultiJson.load(raw_message)
          callback&.call(message)
        end
      rescue StandardError => e
        Rails.logger.error "SSEListener: Error processing message: #{e.message}"
        Rails.logger.error "SSEListener: Backtrace: #{e.backtrace.join("\n")}"
      end
    end

    def valid_json_format?(string)
      return false if string.blank?

      string = string.strip
      (string.start_with?("{") && string.end_with?("}")) ||
        (string.start_with?("[") && string.end_with?("]"))
    end

    def wait_for_subscription
      subscription_future = Concurrent::Promises.future do
        sleep 0.1 while !@subscription_active.true? && !@stopped.true?
        @subscription_active.true?
      end

      begin
        subscription_future.value(5) || @subscription_active.true?
      rescue Concurrent::TimeoutError
        Rails.logger.warn "SSEListener: Timed out waiting for subscription for #{session_key}"
        false
      end
    end
  end
end
