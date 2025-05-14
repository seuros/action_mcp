# frozen_string_literal: true

module ActionMCP
  # Implements the MCP endpoints according to the 2025-03-26 specification.
  # Supports GET for server-initiated SSE streams, POST for client messages
  # (responding with JSON or SSE), and optionally DELETE for session termination.
  class ApplicationController < ActionController::Metal
    REQUIRED_PROTOCOL_VERSION = "2025-03-26"
    MCP_SESSION_ID_HEADER = "Mcp-Session-Id"

    ActionController::API.without_modules(:StrongParameters, :ParamsWrapper).each do |left|
      include left
    end
    include Engine.routes.url_helpers
    include JSONRPC_Rails::ControllerHelpers
    include ActionController::Live

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

    # --- MCP UnifiedController actions ---

    # Handles GET requests for establishing server-initiated SSE streams (2025-03-26 spec).
    # @route GET /
    def show
      if ActionMCP.configuration.post_response_preference == :sse
        unless request.accepts.any? { |type| type.to_s == "text/event-stream" }
          return render_not_acceptable("Client must accept 'text/event-stream' for GET requests.")
        end
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

      last_event_id = request.headers["Last-Event-ID"].presence
      Rails.logger.info "Unified SSE (GET): Resuming from Last-Event-ID: #{last_event_id}" if last_event_id

      response.headers["Content-Type"] = "text/event-stream"
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["Connection"] = "keep-alive"

      Rails.logger.info "Unified SSE (GET): Starting stream for session: #{session.id}"

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
            Rails.logger.info "Unified SSE (GET): Sending #{missed_events.size} missed events for session: #{session.id}"
            missed_events.each do |event|
              sse.write(event.to_sse)
            end
          else
            Rails.logger.info "Unified SSE (GET): No missed events to send for session: #{session.id}"
          end
        rescue StandardError => e
          Rails.logger.error "Unified SSE (GET): Error sending missed events: #{e.message}"
        end
      end

      heartbeat_interval = ActionMCP.configuration.sse_heartbeat_interval || 15.seconds
      heartbeat_sender = lambda do
        if connection_active.true? && !response.stream.closed?
          begin
            future = Concurrent::Promises.future { write_sse_event(sse, session, { type: "ping" }) }
            future.value!(5)
            if heartbeat_active.true?
              heartbeat_task = Concurrent::ScheduledTask.execute(heartbeat_interval, &heartbeat_sender)
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

      heartbeat_task = Concurrent::ScheduledTask.execute(heartbeat_interval, &heartbeat_sender)
      sleep 0.1 while connection_active.true? && !response.stream.closed?
    rescue ActionController::Live::ClientDisconnected, IOError => e
      Rails.logger.debug "Unified SSE (GET): Client disconnected for session: #{session&.id}: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Unified SSE (GET): Unexpected error for session: #{session&.id}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    ensure
      Rails.logger.debug "Unified SSE (GET): Cleaning up connection for session: #{session&.id}"
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
    # @route POST /mcp
    def create
      unless accepts_valid_content_types?
        return render_not_acceptable("Client must accept 'application/json' and 'text/event-stream'")
      end

      is_initialize_request = check_if_initialize_request(jsonrpc_params)
      session_initially_missing = extract_session_id.nil?
      session = mcp_session

      unless is_initialize_request
        if session_initially_missing
          return render_bad_request("Mcp-Session-Id header is required for this request.")
        elsif session.nil? || session.new_record?
          return render_not_found("Session not found.")
        elsif session.status == "closed"
          return render_not_found("Session has been terminated.")
        end
      end

      if session.new_record?
        session.save!
        response.headers[MCP_SESSION_ID_HEADER] = session.id
      end

      transport_handler = Server::TransportHandler.new(session)
      json_rpc_handler = Server::JsonRpcHandler.new(transport_handler)
      handler_results = json_rpc_handler.call(jsonrpc_params)
      process_handler_results(handler_results, session, session_initially_missing, is_initialize_request)
    rescue ActionController::Live::ClientDisconnected, IOError => e
      Rails.logger.debug "Unified SSE (POST): Client disconnected during response: #{e.message}"
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
    # @route DELETE /
    def destroy
      session_id_from_header = extract_session_id
      return render_bad_request("Mcp-Session-Id header is required for DELETE requests.") unless session_id_from_header

      session = Session.find_by(id: session_id_from_header)
      if session.nil?
        return render_not_found("Session not found.")
      elsif session.status == "closed"
        return head :no_content
      end

      begin
        session.close!
        Rails.logger.info "Unified DELETE: Terminated session: #{session.id}"
        head :no_content
      rescue StandardError => e
        Rails.logger.error "Unified DELETE: Error terminating session #{session.id}: #{e.class} - #{e.message}"
        render_internal_server_error("Failed to terminate session.")
      end
    end

    private

    # Finds an existing session based on header or param, or initializes a new one.
    # Note: This doesn't save the new session; that happens upon first use or explicitly.
    def find_or_initialize_session
      session_id = extract_session_id
      if session_id
        session = Session.find_by(id: session_id)
        if session && session.protocol_version != self.class::REQUIRED_PROTOCOL_VERSION
          session.update!(protocol_version: self.class::REQUIRED_PROTOCOL_VERSION)
        end
        session
      else
        Session.new(protocol_version: self.class::REQUIRED_PROTOCOL_VERSION)
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

    # Checks if the parsed body represents an 'initialize' request.
    def check_if_initialize_request(payload)
      return false unless payload.is_a?(JSON_RPC::Request) && !jsonrpc_params_batch?
      payload.method == "initialize"
    end

    # Processes the results from the JsonRpcHandler.
    def process_handler_results(results, session, session_initially_missing, is_initialize_request)
      results ||= {}
      is_notification = jsonrpc_params.is_a?(JSON_RPC::Notification)
      request_id = nil
      if results.is_a?(Hash)
        request_id = results[:request_id] || results[:id]
        request_id ||= results[:payload][:id] if results[:payload].is_a?(Hash) && results[:payload][:id]
      end
      result_type = results[:type]
      result_payload = results[:payload] || {}
      result_payload[:id] = request_id if result_payload.is_a?(Hash) && request_id && !result_payload.key?(:id)

      case result_type
      when :error
        error_payload = result_payload
        error_payload[:id] = request_id if error_payload.is_a?(Hash) && !error_payload.key?(:id) && request_id
        render json: error_payload, status: results.fetch(:status, :bad_request)
      when :notifications_only
        head :accepted
      when :responses
        server_preference = ActionMCP.configuration.post_response_preference
        use_sse = (server_preference == :sse)
        add_session_header = is_initialize_request && session_initially_missing && session.persisted?
        if use_sse
          render_sse_response(result_payload, session, add_session_header)
        else
          render_json_response(result_payload, session, add_session_header)
        end
      else
        Rails.logger.error "Unknown handler result type: #{result_type.inspect}"
        if is_notification
          head :accepted
        else
          render json: {
            jsonrpc: "2.0",
            id: request_id,
            result: result_payload
          }, status: :ok
        end
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
      write_sse_event(sse, session, payload)
    ensure
      sse&.close
      begin
        response.stream&.close
      rescue StandardError
        nil
      end
      Rails.logger.debug "Unified SSE (POST): Response stream closed."
    end

    # Helper to write a JSON payload as an SSE event with a unique ID.
    # Also stores the event for potential resumability.
    def write_sse_event(sse, session, payload)
      event_id = session.increment_sse_counter!
      data = payload.is_a?(String) ? payload : MultiJson.dump(payload)
      sse_event = "id: #{event_id}\ndata: #{data}\n\n"
      sse.write(sse_event)
      return unless ActionMCP.configuration.enable_sse_resumability
      begin
        session.store_sse_event(event_id, payload, session.max_stored_sse_events)
      rescue StandardError => e
        Rails.logger.error "Failed to store SSE event for resumability: #{e.message}"
      end
    end

    # Helper to clean up old SSE events for a session
    def cleanup_old_sse_events(session)
      return unless ActionMCP.configuration.enable_sse_resumability
      begin
        retention_period = session.sse_event_retention_period
        count = session.cleanup_old_sse_events(retention_period)
        Rails.logger.debug "Cleaned up #{count} old SSE events for session: #{session.id}" if count.positive?
      rescue StandardError => e
        Rails.logger.error "Error cleaning up old SSE events: #{e.message}"
      end
    end

    def format_tools_list(tools, session)
      protocol_version = session.protocol_version || ActionMCP.configuration.protocol_version
      tools.map { |tool| tool.klass.to_h(protocol_version: protocol_version) }
    end

    # --- Error Rendering Methods ---

    # Renders a 400 Bad Request response with a JSON-RPC-like error structure.
    def render_bad_request(message = "Bad Request")
      render json: { jsonrpc: "2.0", error: { code: -32_600, message: message } }
    end

    # Renders a 404 Not Found response with a JSON-RPC-like error structure.
    def render_not_found(message = "Not Found")
      render json: { jsonrpc: "2.0", error: { code: -32_001, message: message } }
    end

    # Renders a 405 Method Not Allowed response.
    def render_method_not_allowed(message = "Method Not Allowed")
      render json: { jsonrpc: "2.0", error: { code: -32_601, message: message } }
    end

    # Renders a 406 Not Acceptable response.
    def render_not_acceptable(message = "Not Acceptable")
      render json: { jsonrpc: "2.0", error: { code: -32_002, message: message } }
    end

    # Renders a 501 Not Implemented response.
    def render_not_implemented(message = "Not Implemented")
      render json: { jsonrpc: "2.0", error: { code: -32_003, message: message } }
    end

    # Renders a 500 Internal Server Error response.
    def render_internal_server_error(message = "Internal Server Error", id = nil)
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_000, message: message } }
    end
  end
end
