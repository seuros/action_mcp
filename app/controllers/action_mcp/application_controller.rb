# frozen_string_literal: true

module ActionMCP
  # Implements the MCP endpoints according to the 2025-03-26 specification.
  # Supports GET for server-initiated SSE streams, POST for client messages
  # (responding with JSON or SSE), and optionally DELETE for session termination.
  class ApplicationController < ActionController::API
    MCP_SESSION_ID_HEADER = "Mcp-Session-Id"

    include Engine.routes.url_helpers
    include JSONRPC_Rails::ControllerHelpers
    include ActionController::Live
    include ActionController::Instrumentation

    # Provides the ActionMCP::Session for the current request.
    # Handles finding existing sessions via header/param or initializing a new one.
    # Specific controllers/handlers might need to enforce session ID presence based on context.
    # @return [ActionMCP::Session] The session object (might be unsaved if new)
    def mcp_session
      @mcp_session ||= find_or_initialize_session
    end

    # Provides a unique key for caching or pub/sub based on the session ID.
    # Ensures mcp_session is called first to establish the session ID.
    # @return [String] The session key string.
    def session_key
      @session_key ||= "action_mcp-sessions-#{mcp_session.id}"
    end

    # Handles GET requests for establishing server-initiated SSE streams (2025-03-26 spec).
    # <rails-lens:routes:begin>
    # ROUTE: /, name: mcp_get, via: GET
    # <rails-lens:routes:end>
    def show
      unless request.accepts.any? { |type| type.to_s == "text/event-stream" }
        return render_not_acceptable("Client must accept 'text/event-stream' for GET requests.")
      end

      session_id_from_header = extract_session_id
      return render_bad_request("Mcp-Session-Id header is required for GET requests.") unless session_id_from_header

      session = mcp_session
      if session.nil? || session.new_record?
        return render_not_found("Session not found.")
      elsif !session.initialized?
        return render_bad_request("Session is not fully initialized.")
      elsif session.status == "closed"
        return render_not_found("Session has been terminated.")
      end

      # Authenticate the request via gateway
      authenticate_gateway!
      return if performed?

      last_event_id = request.headers["Last-Event-ID"].presence
      if last_event_id && ActionMCP.configuration.verbose_logging
        Rails.logger.info "Unified SSE (GET): Resuming from Last-Event-ID: #{last_event_id}"
      end

      response.headers["Content-Type"] = "text/event-stream"
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"
      # Add MCP-Protocol-Version header for established sessions
      response.headers["MCP-Protocol-Version"] = session.protocol_version

      if ActionMCP.configuration.verbose_logging
        Rails.logger.info "Unified SSE (GET): Starting stream for session: #{session.id}"
      end

      sse = SSE.new(response.stream)
      listener = SSEListener.new(session)
      connection_active = Concurrent::AtomicBoolean.new
      connection_active.make_true
      heartbeat_active = Concurrent::AtomicBoolean.new
      heartbeat_active.make_true
      heartbeat_task = nil

      listener_started = listener.start do |message|
        write_sse_event(sse, session, message)
      end

      unless listener_started
        Rails.logger.error "Unified SSE (GET): Listener failed to activate for session: #{session.id}"
        connection_active.make_false
        return
      end

      if last_event_id.present? && last_event_id.to_i.positive?
        begin
          missed_events = session.get_sse_events_after(last_event_id.to_i)
          if missed_events.any?
            if ActionMCP.configuration.verbose_logging
              Rails.logger.info "Unified SSE (GET): Sending #{missed_events.size} missed events for session: #{session.id}"
            end
            missed_events.each do |event|
              sse.write(event.to_sse)
            end
          elsif ActionMCP.configuration.verbose_logging
            if ActionMCP.configuration.verbose_logging
              Rails.logger.info "Unified SSE (GET): No missed events to send for session: #{session.id}"
            end
          end
        rescue StandardError => e
          Rails.logger.error "Unified SSE (GET): Error sending missed events: #{e.message}"
        end
      end

      heartbeat_interval = ActionMCP.configuration.sse_heartbeat_interval || 15.seconds
      heartbeat_sender = lambda do
        if connection_active.true? && !response.stream.closed?
          begin
            # Send a proper JSON-RPC notification for heartbeat
            ping_notification = {
              jsonrpc: "2.0",
              method: "notifications/ping",
              params: {}
            }
            future = Concurrent::Promises.future { write_sse_event(sse, session, ping_notification) }
            future.value!(5)
            if heartbeat_active.true?
              heartbeat_task = Concurrent::ScheduledTask.execute(heartbeat_interval, &heartbeat_sender)
            end
          rescue Concurrent::TimeoutError
            Rails.logger.warn "Unified SSE (GET): Heartbeat timed out for session: #{session.id}, closing."
            connection_active.make_false
          rescue StandardError => e
            if ActionMCP.configuration.verbose_logging
              Rails.logger.debug "Unified SSE (GET): Heartbeat error for session: #{session.id}: #{e.message}"
            end
            connection_active.make_false
          end
        else
          heartbeat_active.make_false
        end
      end

      heartbeat_task = Concurrent::ScheduledTask.execute(heartbeat_interval, &heartbeat_sender)
      sleep 0.1 while connection_active.true? && !response.stream.closed?
    rescue ActionController::Live::ClientDisconnected, IOError => e
      if ActionMCP.configuration.verbose_logging
        Rails.logger.debug "Unified SSE (GET): Client disconnected for session: #{session&.id}: #{e.message}"
      end
    rescue StandardError => e
      Rails.logger.error "Unified SSE (GET): Unexpected error for session: #{session&.id}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    ensure
      if ActionMCP.configuration.verbose_logging
        Rails.logger.debug "Unified SSE (GET): Cleaning up connection for session: #{session&.id}"
      end
      heartbeat_active&.make_false
      heartbeat_task&.cancel
      listener&.stop
      cleanup_old_sse_events(session) if session
      sse&.close
      begin
        response.stream&.close
      rescue StandardError
        nil
      end
    end

    # Handles POST requests containing client JSON-RPC messages according to 2025-03-26 spec.
    # <rails-lens:routes:begin>
    # ROUTE: /, name: mcp_post, via: POST
    # <rails-lens:routes:end>
    def create
      unless post_accept_headers_valid?
        id = extract_jsonrpc_id_from_request
        return render_not_acceptable(post_accept_headers_error_message, id)
      end

      # Reject JSON-RPC batch requests as per MCP 2025-06-18 spec
      return render_bad_request("JSON-RPC batch requests are not supported", nil) if jsonrpc_params_batch?

      is_initialize_request = check_if_initialize_request(jsonrpc_params)
      session_initially_missing = extract_session_id.nil?
      session = mcp_session

      # Validate MCP-Protocol-Version header for non-initialize requests
      return unless validate_protocol_version_header

      unless initialization_related_request?(jsonrpc_params)
        if session_initially_missing
          id = jsonrpc_params.respond_to?(:id) ? jsonrpc_params.id : nil
          return render_bad_request("Mcp-Session-Id header is required for this request.", id)
        elsif session.nil? || session.new_record?
          id = jsonrpc_params.respond_to?(:id) ? jsonrpc_params.id : nil
          return render_not_found("Session not found.", id)
        elsif session.status == "closed"
          id = jsonrpc_params.respond_to?(:id) ? jsonrpc_params.id : nil
          return render_not_found("Session has been terminated.", id)
        end
      end

      if session.new_record?
        session.save!
        response.headers[MCP_SESSION_ID_HEADER] = session.id
      end

      # Authenticate the request via gateway (skipped for initialization-related requests)
      if initialization_related_request?(jsonrpc_params)
        # Skipping authentication for initialization request: #{jsonrpc_params.method}
      else
        authenticate_gateway!
        return if performed?
      end

      # Use return mode for the transport handler when we need to capture responses
      transport_handler = Server::TransportHandler.new(session, messaging_mode: :return)
      json_rpc_handler = Server::JsonRpcHandler.new(transport_handler)

      result = json_rpc_handler.call(jsonrpc_params)
      process_handler_results(result, session, session_initially_missing, is_initialize_request)
    rescue ActionController::Live::ClientDisconnected, IOError => e
      if ActionMCP.configuration.verbose_logging
        Rails.logger.debug "Unified SSE (POST): Client disconnected during response: #{e.message}"
      end
      begin
        response.stream&.close
      rescue StandardError
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Unified POST Error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      id = begin
        jsonrpc_params.respond_to?(:id) ? jsonrpc_params.id : nil
      rescue StandardError
        nil
      end
      render_internal_server_error("An unexpected error occurred.", id) unless performed?
    end

    # Handles DELETE requests for session termination (2025-03-26 spec).
    # <rails-lens:routes:begin>
    # ROUTE: /, name: mcp_delete, via: DELETE
    # <rails-lens:routes:end>
    def destroy
      session_id_from_header = extract_session_id
      return render_bad_request("Mcp-Session-Id header is required for DELETE requests.") unless session_id_from_header

      session = Server.session_store.load_session(session_id_from_header)
      if session.nil?
        return render_not_found("Session not found.")
      elsif session.status == "closed"
        return head :no_content
      end

      # Authenticate the request via gateway
      authenticate_gateway!
      return if performed?

      begin
        session.close!
        Rails.logger.info "Unified DELETE: Terminated session: #{session.id}" if ActionMCP.configuration.verbose_logging
        head :no_content
      rescue StandardError => e
        Rails.logger.error "Unified DELETE: Error terminating session #{session.id}: #{e.class} - #{e.message}"
        render_internal_server_error("Failed to terminate session.")
      end
    end

    private

    # Validates the MCP-Protocol-Version header for non-initialization requests
    # Returns true if valid, renders error and returns false if invalid
    def validate_protocol_version_header
      # Skip validation for initialization-related requests
      return true if initialization_related_request?(jsonrpc_params)

      # Check for both case variations of the header (spec uses MCP-Protocol-Version)
      header_version = request.headers["MCP-Protocol-Version"] || request.headers["mcp-protocol-version"]
      session = mcp_session

      # If header is missing, assume 2025-06-18 for backward compatibility as per spec
      if header_version.nil?
        ActionMCP.logger.debug "MCP-Protocol-Version header missing, assuming 2025-06-18 for backward compatibility"
        return true
      end

      # Handle array values (take the last one as per TypeScript SDK)
      header_version = header_version.last if header_version.is_a?(Array)

      # Check if the header version is supported
      unless ActionMCP::SUPPORTED_VERSIONS.include?(header_version)
        supported_versions = ActionMCP::SUPPORTED_VERSIONS.join(", ")
        ActionMCP.logger.warn "Unsupported MCP-Protocol-Version: #{header_version}. Supported versions: #{supported_versions}"
        render_protocol_version_error("Unsupported MCP-Protocol-Version: #{header_version}. Supported versions: #{supported_versions}")
        return false
      end

      # If we have an initialized session, check if the header matches the negotiated version
      if session&.initialized?
        negotiated_version = session.protocol_version
        if header_version != negotiated_version
          ActionMCP.logger.warn "MCP-Protocol-Version mismatch: header=#{header_version}, negotiated=#{negotiated_version}"
          render_protocol_version_error("MCP-Protocol-Version header (#{header_version}) does not match negotiated version (#{negotiated_version})")
          return false
        end
      end

      ActionMCP.logger.debug "MCP-Protocol-Version header validation passed: #{header_version}"
      true
    end

    # Finds an existing session based on header or param, or initializes a new one.
    # Note: This doesn't save the new session; that happens upon first use or explicitly.
    def find_or_initialize_session
      session_id = extract_session_id
      session_store = ActionMCP::Server.session_store

      if session_id
        session_store.load_session(session_id)
      else
        session_store.create_session(nil, protocol_version: ActionMCP::DEFAULT_PROTOCOL_VERSION)
      end
    end

    # @return [String, nil] The extracted session ID or nil if not found.
    def extract_session_id
      request.headers[MCP_SESSION_ID_HEADER].presence
    end

    # Checks if the client's Accept header includes the required types.
    def accepts_valid_content_types?
      request.accepts.any? { |type| type.to_s == "application/json" } &&
        request.accepts.any? { |type| type.to_s == "text/event-stream" }
    end

    # Checks if the Accept headers for POST are valid according to server preference.
    def post_accept_headers_valid?
      if ActionMCP.configuration.post_response_preference == :sse
        accepts_valid_content_types?
      else
        request.accepts.any? { |type| type.to_s == "application/json" }
      end
    end

    # Returns the appropriate error message for POST Accept header validation.
    def post_accept_headers_error_message
      if ActionMCP.configuration.post_response_preference == :sse
        "Client must accept 'application/json' and 'text/event-stream'"
      else
        "Client must accept 'application/json'"
      end
    end

    # Checks if the parsed body represents an 'initialize' request.
    def check_if_initialize_request(payload)
      return false unless payload.is_a?(JSON_RPC::Request) && !jsonrpc_params_batch?

      payload.method == "initialize"
    end

    # Checks if the request is related to initialization (initialize or notifications/initialized)
    def initialization_related_request?(payload)
      return false unless payload.respond_to?(:method) && !jsonrpc_params_batch?

      %w[initialize notifications/initialized].include?(payload.method)
    end

    # Processes the results from the JsonRpcHandler.
    def process_handler_results(result, session, session_initially_missing, is_initialize_request)
      # Handle empty result (notifications)
      return head :accepted if result.nil?

      # Convert to hash for rendering
      payload = if result.respond_to?(:to_h)
                  result.to_h
      elsif result.respond_to?(:to_json)
                  JSON.parse(result.to_json)
      else
                  result
      end

      # Determine response format
      server_preference = ActionMCP.configuration.post_response_preference
      use_sse = (server_preference == :sse)
      add_session_header = is_initialize_request && session_initially_missing && session.persisted?

      if use_sse
        render_sse_response(payload, session, add_session_header)
      else
        render_json_response(payload, session, add_session_header)
      end
    end

    # Renders the JSON-RPC response(s) as a direct JSON HTTP response.
    def render_json_response(payload, session, add_session_header)
      response.headers[MCP_SESSION_ID_HEADER] = session.id if add_session_header
      # Add MCP-Protocol-Version header if session has been initialized
      response.headers["MCP-Protocol-Version"] = session.protocol_version if session&.initialized?
      response.headers["Content-Type"] = "application/json"
      render json: payload, status: :ok
    end

    # Renders the JSON-RPC response(s) as an SSE stream.
    def render_sse_response(payload, session, add_session_header)
      response.headers[MCP_SESSION_ID_HEADER] = session.id if add_session_header
      # Add MCP-Protocol-Version header if session has been initialized
      response.headers["MCP-Protocol-Version"] = session.protocol_version if session&.initialized?
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"
      sse = SSE.new(response.stream)
      write_sse_event(sse, session, payload)
    ensure
      sse&.close
      begin
        response.stream&.close
      rescue StandardError
        nil
      end
      Rails.logger.debug "Unified SSE (POST): Response stream closed." if ActionMCP.configuration.verbose_logging
    end

    # Helper to write a JSON payload as an SSE event with a unique ID.
    # Also stores the event for potential resumability.
    def write_sse_event(sse, session, payload)
      event_id = session.increment_sse_counter!
      # Ensure we're always writing valid JSON strings
      data = case payload
      when String
               payload
      when Hash
               MultiJson.dump(payload)
      else
               MultiJson.dump(payload.to_h)
      end
      # Use the SSE class's write method with proper options
      # According to MCP spec, we need to send with event type "message"
      sse.write(data, event: "message", id: event_id)

      begin
        session.store_sse_event(event_id, payload, session.max_stored_sse_events)
      rescue StandardError => e
        Rails.logger.error "Failed to store SSE event for resumability: #{e.message}"
      end
    end

    # Helper to clean up old SSE events for a session
    def cleanup_old_sse_events(session)
      retention_period = session.sse_event_retention_period
      count = session.cleanup_old_sse_events(retention_period)
      if count.positive? && ActionMCP.configuration.verbose_logging
        Rails.logger.debug "Cleaned up #{count} old SSE events for session: #{session.id}"
      end
    rescue StandardError => e
      Rails.logger.error "Error cleaning up old SSE events: #{e.message}"
    end

    def format_tools_list(tools, session)
      protocol_version = session.protocol_version || ActionMCP.configuration.protocol_version
      tools.map { |tool| tool.klass.to_h(protocol_version: protocol_version) }
    end

    # --- Error Rendering Methods ---

    # Renders a 400 Bad Request response with a JSON-RPC-like error structure.
    def render_bad_request(message = "Bad Request", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_600, message: message } }
    end

    # Renders a 400 Bad Request response for protocol version errors as per MCP spec
    def render_protocol_version_error(message = "Protocol Version Error", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_000, message: message } }, status: :bad_request
    end

    # Renders a 404 Not Found response with a JSON-RPC-like error structure.
    def render_not_found(message = "Not Found", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_001, message: message } }
    end

    # Renders a 405 Method Not Allowed response.
    def render_method_not_allowed(message = "Method Not Allowed", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_601, message: message } }
    end

    # Renders a 406 Not Acceptable response.
    def render_not_acceptable(message = "Not Acceptable", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_002, message: message } }
    end

    # Renders a 501 Not Implemented response.
    def render_not_implemented(message = "Not Implemented", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_003, message: message } }
    end

    # Renders a 500 Internal Server Error response.
    def render_internal_server_error(message = "Internal Server Error", id = nil)
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_000, message: message } }
    end

    # Extract JSON-RPC ID from request
    def extract_jsonrpc_id_from_request
      # Try to get from already parsed jsonrpc_params first
      if defined?(jsonrpc_params) && jsonrpc_params
        return jsonrpc_params.respond_to?(:id) ? jsonrpc_params.id : nil
      end

      # Otherwise try to parse from raw body, this need refactoring
      return nil unless request.post? && request.content_type&.include?("application/json")

      begin
        body = request.body.read
        request.body.rewind # Reset for subsequent reads
        json = JSON.parse(body)
        json["id"]
      rescue JSON::ParserError, StandardError
        nil
      end
    end

    # Authenticates the request using the configured gateway
    def authenticate_gateway!
      # Skip authentication for initialization-related requests in POST method
      if request.post? && defined?(jsonrpc_params) && jsonrpc_params && initialization_related_request?(jsonrpc_params)
        return
      end

      gateway_class = ActionMCP.configuration.gateway_class
      return unless gateway_class # Skip if no gateway configured

      begin
        gateway = gateway_class.new(request)
        gateway.call
      rescue ActionMCP::UnauthorizedError => e
        render_unauthorized(e.message)
      rescue StandardError => e
        Rails.logger.error "Gateway authentication error: #{e.class} - #{e.message}"
        render_unauthorized("Authentication system error")
      end
    end

    # Renders an unauthorized response
    def render_unauthorized(message = "Unauthorized", id = nil)
      id ||= extract_jsonrpc_id_from_request

      # Return JSON-RPC error with 200 status as per MCP specification
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_000, message: message } }
    end
  end
end
