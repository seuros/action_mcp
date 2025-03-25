# frozen_string_literal: true

module ActionMCP
  class SSEController < MCPController
    HEARTBEAT_INTERVAL = 30 # in seconds
    INITIAL_CONNECTION_TIMEOUT = 5 # in seconds
    include ActionController::Live

    # @route GET /sse (sse_out)
    def events
      # Set headers for SSE
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"

      # Send the endpoint URL to the client
      send_endpoint_event(sse_in_url)

      Rails.logger.info "SSE: Starting connection for session: #{session_id}"

      # Use Concurrent primitives for state management
      message_received = Concurrent::AtomicBoolean.new(false)
      connection_active = Concurrent::AtomicBoolean.new(true)

      begin
        # Create SSE instance
        sse = SSE.new(response.stream)

        # Start the connection monitor using a proper scheduled task
        timeout_task = Concurrent::ScheduledTask.execute(INITIAL_CONNECTION_TIMEOUT) do
          unless message_received.true?
            Rails.logger.warn "No message received within #{INITIAL_CONNECTION_TIMEOUT} seconds, closing connection for session: #{session_id}"
            error = build_timeout_error
            # Safely write error and close the stream
            Concurrent::Promise.execute do
              sse.write(error) rescue nil
              response.stream.close rescue nil
              connection_active.make_false
            end
          end
        end

        # Initialize the listener
        listener = SSEListener.new(mcp_session)
        listener_started = listener.start do |message|
          message_received.make_true
          sse.write(message)
        end

        unless listener_started
          Rails.logger.error "Listener failed to activate for session: #{session_id}"
          error = build_listener_error
          sse.write(error)
          connection_active.make_false
          return
        end

        # Schedule heartbeats using a proper timer
        heartbeat = Concurrent::TimerTask.new(
          execution_interval: HEARTBEAT_INTERVAL,
          timeout_interval: 5 # Timeout for heartbeat operation
        ) do
          if connection_active.true? && !response.stream.closed?
            begin
              sse.write({ping: true})
            rescue StandardError => e
              Rails.logger.debug "SSE: Heartbeat error: #{e.message}"
              connection_active.make_false
            end
          else
            raise Concurrent::CancelledOperationError
          end
        end
        heartbeat.execute

        # Wait for connection to be closed or cancelled
        while connection_active.true? && !response.stream.closed?
          sleep 0.1
        end
      rescue ActionController::Live::ClientDisconnected, IOError => e
        Rails.logger.debug "SSE: Client disconnected: #{e.message}"
      rescue StandardError => e
        Rails.logger.error "SSE: Unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      ensure
        # Clean up resources
        timeout_task&.cancel
        heartbeat&.shutdown
        listener&.stop
        response.stream.close rescue nil

        Rails.logger.debug "SSE: Connection cleaned up for session: #{session_id}"
      end
    end

    private

    def build_timeout_error
      JsonRpc::Response.new(
        id: SecureRandom.uuid_v7,
        error: JsonRpc::JsonRpcError.new(
          :server_error,
          message: "No message received within initial connection timeout"
        ).to_h
      ).to_h
    end

    def build_listener_error
      JsonRpc::Response.new(
        id: SecureRandom.uuid_v7,
        error: JsonRpc::JsonRpcError.new(
          :server_error,
          message: "Failed to establish server connection"
        ).to_h
      ).to_h
    end

    def send_endpoint_event(messages_url)
      endpoint = "#{messages_url}?session_id=#{session_id}"
      SSE.new(response.stream, event: "endpoint").write(endpoint)
    end

    def default_url_options
      { host: request.host, port: request.port }
    end

    def mcp_session
      @mcp_session ||= Session.new
    end

    def session_id
      mcp_session.id
    end

    def cache_key
      mcp_session.session_key
    end
  end

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
    def start(&callback)
      Rails.logger.debug "Starting listener for channel: #{session_key}"

      success_callback = lambda {
        Rails.logger.info "Successfully subscribed to channel: #{session_key}"
        @subscription_active.make_true
      }

      # Set up message callback
      message_callback = lambda { |raw_message|
        return if @stopped.true?

        begin
          # Try to parse the message if it's JSON
          message = MultiJson.load(raw_message)
          # Send the message to the callback
          callback.call(message) if callback
        rescue StandardError => e
          Rails.logger.error "Error processing message: #{e.message}"
          # Still try to send the raw message as a fallback
          callback.call(raw_message) if callback
        end
      }

      # Subscribe using the ActionCable adapter
      adapter.subscribe(session_key, message_callback, success_callback)

      # Use a future with timeout to check subscription status
      subscription_future = Concurrent::Promises.future do
        while !@subscription_active.true? && !@stopped.true?
          sleep 0.1
        end
        @subscription_active.true?
      end

      # Wait up to 1 second for subscription to be established
      begin
        subscription_result = subscription_future.value(1)
        subscription_result || @subscription_active.true?
      rescue Concurrent::TimeoutError
        Rails.logger.warn "Timed out waiting for subscription activation"
        false
      end
    end

    def stop
      @stopped.make_true
      if (mcp_session = Session.find_by(id: session_key))
        mcp_session.close
      end
      Rails.logger.debug "Unsubscribed from: #{session_key}"
    end
  end
end
