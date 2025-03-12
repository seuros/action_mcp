module ActionMCP
  class SSEController < ApplicationController
    HEARTBEAT_INTERVAL = 10
    INITIALIZATION_TIMEOUT = 2
    include ActionController::Live

    # @route GET /sse (sse_out)
    def events
      # Set headers first
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"

      listener = nil
      begin
        # Now start streaming - send endpoint
        send_endpoint_event(sse_in_url)

        # Start listener and process messages via the transport
        listener = SseListener.new(session_key)
        if listener.start do |message|
          begin
            # Send with proper SSE formatting
            sse = SSE.new(response.stream)
            sse.write(message)
          rescue => e
            Rails.logger.error "Error sending SSE message: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
          end
        end

          # Heartbeat loop
          until response.stream.closed?
            sleep HEARTBEAT_INTERVAL
            send_ping!
          end
        else
          Rails.logger.error "Listener failed to activate for session: #{session_id}"
          raise "Failed to establish subscription"
        end
      rescue ActionController::Live::ClientDisconnected, IOError => e
        Rails.logger.debug "SSE: Expected disconnection: #{e.message}"
      rescue => e
        Rails.logger.error "SSE: Unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      ensure
        listener&.stop
        response.stream.close
        Rails.logger.debug "SSE: Connection closed for session: #{session_id}"
      end
    end

    private

    def send_endpoint_event(messages_url)
      endpoint = "#{messages_url}?session_id=#{session_id}"
      SSE.new(response.stream,
              event: "endpoint")
         .write(endpoint)
    end

    def send_ping!
      SSE.new(response.stream,
              event: "ping")
         .write(Time.now.to_i)
    end

    def default_url_options
      { host: request.host, port: request.port }
    end

    def session_id
      @session_id ||= SecureRandom.hex(6)
    end
  end

  class SseListener
    attr_reader :session_key, :adapter

    def initialize(session_key)
      @session_key = session_key
      @adapter = ActionMCP::Server.server.pubsub
      @stopped = false
      @subscription_active = false
    end

    # Start listening using ActionCable's PostgreSQL adapter
    def start(&callback)
      Rails.logger.debug "Starting listener for channel: #{session_key}"

      # Set up success callback
      success_callback = -> {
        Rails.logger.debug "Successfully subscribed to channel: #{session_key}"
        @subscription_active = true
      }

      # Set up message callback with detailed debugging
      message_callback = ->(raw_message) {
        # Rails.logger.debug "\e[31mReceived raw message: #{raw_message.inspect}\e[0m"

        begin
          # Try to parse the message if it's JSON
          message = raw_message.is_a?(String) ? MultiJson.load(raw_message) : raw_message

          # Send the message to the callback
          callback.call(message) if callback && !@stopped
        rescue => e
          # Still try to send the raw message as a fallback
          callback.call(raw_message) if callback && !@stopped
        end
      }

      # Subscribe using the ActionCable adapter
      adapter.subscribe(session_key, message_callback, success_callback)

      # Give some time for the subscription to be established
      sleep 1.5

      # Check if subscription was successful
      if @subscription_active
        Rails.logger.debug "Subscription confirmed active for: #{session_key}"
        true
      else
        Rails.logger.error "Failed to activate subscription for: #{session_key}"
        false
      end
    end

    def stop
      Rails.logger.debug "Stopping listener for: #{session_key}"
      @stopped = true

      # Unsubscribe using the correct method signature
      begin
        # Create a dummy callback that matches the one we provided in start
        dummy_callback = ->(_) { }
        adapter.unsubscribe(session_key, dummy_callback)
        Rails.logger.debug "Unsubscribed from: #{session_key}"
      rescue => e
        Rails.logger.error "Error unsubscribing from #{session_key}: #{e.message}"
      end
    end

    def active?
      @subscription_active
    end
  end
end
