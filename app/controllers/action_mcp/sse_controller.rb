module ActionMCP
  class SSEController < ApplicationController
    HEARTBEAT_INTERVAL = 30 # TODO: The frequency of pings SHOULD be configurable
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
        # Create SSE instance once outside the callback with retry parameter
        sse = SSE.new(response.stream)

        # Start listener and process messages via the transport
        listener = SSEListener.new(mcp_session)
        message_received = false
        if listener.start do |message|
          # Send with proper SSE formatting
          sse.write(message)
          message_received = true
        end
        sleep 1
        # Heartbeat loop
        unless message_received
          Rails.logger.warn "No message received within 1 second, closing connection for session: #{session_id}"
          error = JsonRpc::Response.new(id: SecureRandom.uuid_v7, error: JsonRpc::JsonRpcError.new(:server_error, message: "No message received within 1 second").to_h).to_h
          sse.write(error)
          return
        end

          until response.stream.closed?
            sleep HEARTBEAT_INTERVAL
            # mcp_session.send_ping!
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
        response.stream.close
        listener.stop
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
      @mcp_session ||= Session.new
    end

    def session_id
      @session_id ||= mcp_session.id
    end

    def cache_key
      "action_mcp:session:#{session_id}"
    end
  end

  class SSEListener
    attr_reader :session_key, :adapter
    delegate :session_key, :adapter, to: :@session

    # @param session [ActionMCP::Session]
    def initialize(session)
      @session = session
      @stopped = false
    end

    # Start listening using ActionCable's adapter
    def start(&callback)
      Rails.logger.debug "Starting listener for channel: #{session_key}"

      success_callback = -> {
        puts "Successfully subscribed to channel: #{session_key}"
        @subscription_active = true
      }

      # Set up message callback
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
      @stopped = true
      if (mcp_session = Session.find_by(id: session_key))
        mcp_session.close
      end
      Rails.logger.debug "Unsubscribed from: #{session_key}"
    end
  end
end
