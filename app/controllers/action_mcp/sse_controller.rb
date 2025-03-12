module ActionMCP
  class SSEController < ApplicationController
    HEARTBEAT_INTERVAL = 30 # TODO: The frequency of pings SHOULD be configurable
    INITIALIZATION_TIMEOUT = 2
    include ActionController::Live

    # @route GET /sse (sse_out)
    def events
      # Set headers first
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"

      # Now start streaming - send endpoint
      send_endpoint_event(sse_in_url)

      begin
        # Start listener and process messages via the transport
        listener = SSEListener.new(mcp_session)
        if listener.start do |message|
          # Send with proper SSE formatting
          sse = SSE.new(response.stream)
          sse.write(message)
        end

          # Heartbeat loop
          until response.stream.closed?
            sleep HEARTBEAT_INTERVAL
            mcp_session.send_ping!
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
        listener.stop
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

    def default_url_options
      { host: request.host, port: request.port }
    end

    def mcp_session
      @mcp_session ||= Session.create
    end

    def session_id
      @session_id ||= mcp_session.id
    end
  end

  class SSEListener
    attr_reader :session_key, :adapter
    delegate :session_key, :adapter, to: :@session

    # @param session [ActionMCP::Session]
    def initialize(session)
      @session = session
      @stopped = false
      @subscription_active = false
    end

    # Start listening using ActionCable's adapter
    def start(&callback)
      Rails.logger.debug "Starting listener for channel: #{session_key}"

      # Set up success callback
      success_callback = -> {
        Rails.logger.debug "Successfully subscribed to channel: #{session_key}"
        @subscription_active = true
      }

      # Set up message callback with detailed debugging
      message_callback = ->(raw_message) {
        begin
          # Try to parse the message if it's JSON
          message = MultiJson.load(raw_message)

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
      sleep 0.5

      @subscription_active
    end

    def stop
      Rails.logger.debug "Stopping listener for: #{session_key}"
      @stopped = true

      # Unsubscribe using the correct method signature
      begin
        # Create a dummy callback that matches the one we provided in start
        @session.close!
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
