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

        # Create a thread-safe flag to track if we should continue sending heartbeats
        heartbeat_active = Concurrent::AtomicBoolean.new(true)

        # Setup recurring heartbeat using ScheduledTask with proper cancellation
        heartbeat_task = nil
        heartbeat_sender = lambda do
          if connection_active.true? && !response.stream.closed?
            begin
              # Try to send heartbeat with a controlled execution time
              future = Concurrent::Promises.future do
                ping_request = JSON_RPC::Request.new(
                  id: SecureRandom.uuid_v7, # Generate a unique ID for each ping
                  method: "ping"
                ).to_h
                sse.write(ping_request)
              end

              # Wait for the heartbeat with timeout
              future.value(5) # 5 second timeout

              # Schedule the next heartbeat if this one succeeded
              if heartbeat_active.true?
                heartbeat_task = Concurrent::ScheduledTask.execute(HEARTBEAT_INTERVAL, &heartbeat_sender)
              end
            rescue Concurrent::TimeoutError
              Rails.logger.warn "SSE: Heartbeat timed out, closing connection"
              connection_active.make_false
            rescue StandardError => e
              Rails.logger.debug "SSE: Heartbeat error: #{e.message}"
              connection_active.make_false
            end
          else
            heartbeat_active.make_false
          end
        end

        # Start the first heartbeat
        heartbeat_task = Concurrent::ScheduledTask.execute(HEARTBEAT_INTERVAL, &heartbeat_sender)

        # Wait for connection to be closed or cancelled
        sleep 0.1 while connection_active.true? && !response.stream.closed?
      rescue ActionController::Live::ClientDisconnected, IOError => e
        Rails.logger.debug "SSE: Client disconnected: #{e.message}"
      rescue StandardError => e
        Rails.logger.error "SSE: Unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      ensure
        # Clean up resources
        timeout_task&.cancel
        heartbeat_active&.make_false  # Signal to stop scheduling new heartbeats
        heartbeat_task&.cancel        # Cancel any pending heartbeat task
        listener&.stop
        mcp_session.close! rescue nil
        response.stream.close rescue nil

        Rails.logger.debug "SSE: Connection cleaned up for session: #{session_id}"
      end
    end

    private

    def build_timeout_error
      JSON_RPC::Response.new(
        id: SecureRandom.uuid_v7,
        error: JSON_RPC::JsonRpcError.new(
          :server_error,
          message: "No message received within initial connection timeout"
        ).to_h
      ).to_h
    end

    def build_listener_error
      JSON_RPC::Response.new(
        id: SecureRandom.uuid_v7,
        error: JSON_RPC::JsonRpcError.new(
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
end
