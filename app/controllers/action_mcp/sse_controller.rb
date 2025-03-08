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

      # in green
      Rails.logger.info "\e[32mSSE: Registering new connection with session ID: #{session_id}\e[0m"

      listener = nil
      begin
        # Now start streaming - send endpoint
        send_endpoint_event(sse_in_url)

        # Get info about the adapter
        adapter = ActionMCP::Server.server.pubsub
        adapter_class = adapter.class.name
        Rails.logger.info "Using pub/sub adapter: #{adapter_class}"

        # Test broadcasting a message
        begin
          test_message = { test: true, timestamp: Time.now.to_i }.to_json
          Rails.logger.info "Testing broadcast with channel: #{session_key}, message: #{test_message}"
          adapter.broadcast(session_key, test_message)
          Rails.logger.info "Broadcast test message successfully"
        rescue => e
          Rails.logger.error "Failed to broadcast test message: #{e.message}"
        end

        # Start listener and process messages via the transport
        listener = SseListener.new(session_key)
        if listener.start do |message|
          begin
            Rails.logger.info "Processing message in controller: #{message.inspect} (#{message.class})"

            # Handle different message formats
            data = case message
                   when String
                     begin
                       # Try to parse as JSON if it's a JSON string
                       JSON.parse(message)
                       message # Return the original string if it parsed successfully
                     rescue JSON::ParserError
                       message # Return the original string if it's not JSON
                     end
                   when Hash, Array
                     message.to_json
                   else
                     message.to_s
                   end

            # Send with proper SSE formatting
            sse = SSE.new(response.stream)
            if message.is_a?(Hash) && message['event']
              # If message has an event field, use it
              sse.write(message['data'] || message, event: message['event'])
            else
              # Otherwise just write the data
              sse.write(data)
            end

            Rails.logger.info "Sent SSE message to client"
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
        Rails.logger.info "SSE: Expected disconnection: #{e.message}"
      rescue => e
        Rails.logger.error "SSE: Unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      ensure
        listener&.stop
        response.stream.close
        Rails.logger.info "SSE: Connection closed for session: #{session_id}"
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
      Rails.logger.info "Starting listener for channel: #{session_key}"

      # Set up success callback
      success_callback = -> {
        Rails.logger.info "Successfully subscribed to channel: #{session_key}"
        @subscription_active = true
      }

      # Set up message callback with detailed debugging
      message_callback = ->(raw_message) {
        Rails.logger.info "Received raw message via adapter: #{raw_message.inspect} (#{raw_message.class})"

        begin
          # Try to parse the message if it's JSON
          message = raw_message.is_a?(String) ? JSON.parse(raw_message) : raw_message
          Rails.logger.info "Processed message: #{message.inspect}"

          # Send the message to the callback
          callback.call(message) if callback && !@stopped
        rescue => e
          Rails.logger.error "Error processing message: #{e.class} - #{e.message}"
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
        Rails.logger.info "Subscription confirmed active for: #{session_key}"
        true
      else
        Rails.logger.error "Failed to activate subscription for: #{session_key}"
        false
      end
    end

    def stop
      Rails.logger.info "Stopping listener for: #{session_key}"
      @stopped = true

      # Unsubscribe using the correct method signature
      begin
        # Create a dummy callback that matches the one we provided in start
        dummy_callback = ->(message) {}
        adapter.unsubscribe(session_key, dummy_callback)
        Rails.logger.info "Unsubscribed from: #{session_key}"
      rescue => e
        Rails.logger.error "Error unsubscribing from #{session_key}: #{e.message}"
      end
    end

    def active?
      @subscription_active
    end
  end

end
