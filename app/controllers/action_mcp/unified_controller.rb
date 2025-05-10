# frozen_string_literal: true

module ActionMCP
  # Handles the unified MCP endpoint for the 2025-03-26 specification.
  # Supports GET for server-initiated SSE streams, POST for client messages
  # (responding with JSON or SSE), and optionally DELETE for session termination.
  class UnifiedController < MCPController
    include JSONRPC_Rails::ControllerHelpers
    include ActionController::Live
    # TODO: Include Instrumentation::ControllerRuntime if needed for metrics

    # Handles GET requests for establishing server-initiated SSE streams (2025-03-26 spec).
    # @route GET /mcp
    def show
      # 1. Check Accept Header
      unless request.accepts.any? { |type| type.to_s == "text/event-stream" }
        return render_not_acceptable("Client must accept 'text/event-stream' for GET requests.")
      end

      # 2. Check Session (Must exist and be initialized)
      session_id_from_header = extract_session_id
      return render_bad_request("Mcp-Session-Id header is required for GET requests.") unless session_id_from_header

      session = mcp_session # Finds based on header
      if session.nil? || session.new_record?
        return render_not_found("Session not found.")
      elsif !session.initialized?
        # Spec doesn't explicitly forbid GET before initialized, but it seems logical
        return render_bad_request("Session is not fully initialized.")
      elsif session.status == "closed"
        return render_not_found("Session has been terminated.")
      end

      # TODO: Handle Last-Event-ID header for stream resumption

      # 3. Set SSE Headers
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"

      Rails.logger.info "Unified SSE (GET): Starting stream for session: #{session.id}"

      # 4. Setup Stream, Listener, and Heartbeat
      sse = SSE.new(response.stream)
      listener = SSEListener.new(session) # Use the listener class (defined below or moved)
      connection_active = Concurrent::AtomicBoolean.new
      connection_active.make_true
      heartbeat_active = Concurrent::AtomicBoolean.new
      heartbeat_active.make_true
      heartbeat_task = nil

      # Start listener
      listener_started = listener.start do |message|
        # Write message using helper to include event ID
        write_sse_event(sse, session, message)
      end

      unless listener_started
        Rails.logger.error "Unified SSE (GET): Listener failed to activate for session: #{session.id}"
        # Don't write error to stream as per spec for GET, just close
        connection_active.make_false
        return # Error logged, connection will close in ensure block
      end

      # Heartbeat sender proc
      heartbeat_sender = lambda do
        if connection_active.true? && !response.stream.closed?
          begin
            # Use helper to send ping with event ID
            future = Concurrent::Promises.future { write_sse_event(sse, session, { type: "ping" }) }
            future.value!(5) # 5 second timeout for write
            if heartbeat_active.true?
              heartbeat_task = Concurrent::ScheduledTask.execute(ActionMCP.configuration.sse_heartbeat_interval,
                                                                 &heartbeat_sender)
            end
          rescue Concurrent::TimeoutError
            Rails.logger.warn "Unified SSE (GET): Heartbeat timed out for session: #{session.id}, closing."
            connection_active.make_false
          rescue StandardError => e
            Rails.logger.debug "Unified SSE (GET): Heartbeat error for session: #{session.id}: #{e.message}"
            connection_active.make_false
          end
        else
          heartbeat_active.make_false
        end
      end

      # Start first heartbeat
      heartbeat_task = Concurrent::ScheduledTask.execute(HEARTBEAT_INTERVAL, &heartbeat_sender)

      # Keep connection alive while active
      sleep 0.1 while connection_active.true? && !response.stream.closed?
    rescue ActionController::Live::ClientDisconnected, IOError => e
      Rails.logger.debug "Unified SSE (GET): Client disconnected for session: #{session&.id}: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Unified SSE (GET): Unexpected error for session: #{session&.id}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    ensure
      # Cleanup
      Rails.logger.debug "Unified SSE (GET): Cleaning up connection for session: #{session&.id}"
      heartbeat_active&.make_false
      heartbeat_task&.cancel
      listener&.stop
      # Don't close the session itself here, it might be used by other connections/requests
      sse&.close
      begin
        response.stream&.close
      rescue StandardError
        nil
      end
    end

    # Handles POST requests containing client JSON-RPC messages according to 2025-03-26 spec.
    # @route POST /mcp
    def create
      # 1. Check Accept Header
      unless accepts_valid_content_types?
        return render_not_acceptable("Client must accept 'application/json' and 'text/event-stream'")
      end

      # Determine if this is an initialize request (before session check)
      is_initialize_request = check_if_initialize_request(jsonrpc_params)

      # 3. Check Session (unless it's an initialize request)
      session_initially_missing = extract_session_id.nil?
      session = mcp_session # This finds or initializes
      unless is_initialize_request
        if session_initially_missing
          return render_bad_request("Mcp-Session-Id header is required for this request.")
        elsif session.nil? || session.new_record? # Should be found if ID was provided
          return render_not_found("Session not found.")
        elsif session.status == "closed"
          return render_not_found("Session has been terminated.")
        end
      end
      if session.new_record?
        session.save
        response.headers[MCP_SESSION_ID_HEADER] = session.id
      end
      # 4. Instantiate Handlers
      transport_handler = Server::TransportHandler.new(session)
      json_rpc_handler = Server::JsonRpcHandler.new(transport_handler)

      # 5. Call Handler
      handler_results = json_rpc_handler.call(jsonrpc_params.to_h)

      # 6. Process Results
      process_handler_results(handler_results, session, session_initially_missing, is_initialize_request)
    rescue ActionController::Live::ClientDisconnected, IOError => e
      # Ensure stream is closed if SSE response was attempted and client disconnected
      Rails.logger.debug "Unified SSE (POST): Client disconnected during response: #{e.message}"
      # Ensure stream is closed, cleanup might happen in ensure block if needed
      begin
        response.stream&.close
      rescue StandardError
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Unified POST Error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      render_internal_server_error("An unexpected error occurred.") unless performed?
    end

    # Handles DELETE requests for session termination (2025-03-26 spec).
    # @route DELETE /mcp
    def destroy
      # 1. Check Session Header
      session_id_from_header = extract_session_id
      return render_bad_request("Mcp-Session-Id header is required for DELETE requests.") unless session_id_from_header

      # 2. Find Session
      # Note: mcp_session helper finds based on header, but doesn't raise error if not found
      session = Session.find_by(id: session_id_from_header)

      if session.nil?
        return render_not_found("Session not found.")
      elsif session.status == "closed"
        # Session already closed, treat as success (idempotent)
        return head :no_content
      end

      # 3. Terminate Session
      begin
        session.close! # This should handle cleanup like unsubscribing etc.
        Rails.logger.info "Unified DELETE: Terminated session: #{session.id}"
        head :no_content
      rescue StandardError => e
        Rails.logger.error "Unified DELETE: Error terminating session #{session.id}: #{e.class} - #{e.message}"
        render_internal_server_error("Failed to terminate session.")
      end
    end

    private

    # Checks if the client's Accept header includes the required types.
    def accepts_valid_content_types?
      request.accepts.any? { |type| type.to_s == "application/json" } &&
        request.accepts.any? { |type| type.to_s == "text/event-stream" }
    end

    # Checks if the parsed body represents an 'initialize' request.
    def check_if_initialize_request(payload)
      return false unless payload.is_a?(JSON_RPC::Request) && !jsonrpc_params_batch?
      payload.method == "initialize"
    end

    # Processes the results from the JsonRpcHandler.
    def process_handler_results(results, session, session_initially_missing, is_initialize_request)
      case results[:type]
      when :error
        # Handle handler-level errors (e.g., batch parse error)
        render json: results[:payload], status: results.fetch(:status, :bad_request)
      when :notifications_only
        # No response needed, just accept
        head :accepted
      when :responses
        # Determine response format based on server preference and client acceptance.
        # Client MUST accept both 'application/json' and 'text/event-stream' (checked earlier).
        server_preference = ActionMCP.configuration.post_response_preference # :json or :sse
        use_sse = (server_preference == :sse)

        # Add session ID header if this was a successful initialize request that created the session
        add_session_header = is_initialize_request && session_initially_missing && session.persisted?

        if use_sse
          render_sse_response(results[:payload], session, add_session_header)
        else
          render_json_response(results[:payload], session, add_session_header)
        end
      else
        # Should not happen
        render_internal_server_error("Unknown handler result type: #{results[:type]}")
      end
    end

    # Renders the JSON-RPC response(s) as a direct JSON HTTP response.
    def render_json_response(payload, session, add_session_header)
      response.headers[MCP_SESSION_ID_HEADER] = session.id if add_session_header
      response.headers["Content-Type"] = "application/json"
      render json: payload, status: :ok
    end

    # Renders the JSON-RPC response(s) as an SSE stream.
    def render_sse_response(payload, session, add_session_header)
      response.headers[MCP_SESSION_ID_HEADER] = session.id if add_session_header
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"

      sse = SSE.new(response.stream)
      # TODO: Add logic for sending related server requests/notifications before/after response?

      if payload.is_a?(Array)
        # Send batched responses as separate events or one event? Spec allows batching.
        # Let's send as one event for now, using one ID for the batch.
      end
      write_sse_event(sse, session, payload)
    ensure
      # Close the stream after sending the response(s)
      sse&.close
      begin
        response.stream&.close
      rescue StandardError
        nil
      end
      Rails.logger.debug "Unified SSE (POST): Response stream closed."
    end

    # Renders a 500 Internal Server Error response.
    def render_internal_server_error(message = "Internal Server Error")
      # Using -32000 for generic server error
      render json: { jsonrpc: "2.0", error: { code: -32_000, message: message } }
    end

    # Helper to write a JSON payload as an SSE event with a unique ID.
    def write_sse_event(sse, session, payload)
      event_id = session.increment_sse_counter!
      # Manually format the SSE event string including the ID
      data = MultiJson.dump(payload)
      sse.stream.write("id: #{event_id}\ndata: #{data}\n\n")
    end

    # TODO: Add methods for handle_get (SSE setup, listener, heartbeat) - Partially Done
    # TODO: Add method for handle_delete (session termination) - DONE (Basic)
  end
end
