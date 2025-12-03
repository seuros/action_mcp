# frozen_string_literal: true

module ActionMCP
  # Implements the MCP endpoints according to the 2025-03-26 specification.
  # Supports GET for server-initiated SSE streams, POST for client messages
  # (responding with JSON or SSE), and optionally DELETE for session termination.
  class ApplicationController < ActionController::API
    MCP_SESSION_ID_HEADER = "Mcp-Session-Id"

    include Engine.routes.url_helpers
    include JSONRPC_Rails::ControllerHelpers
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

    # Handles GET requests - returns 405 Method Not Allowed as per MCP spec.
    # SSE streaming is not supported. Clients should use Tasks for async operations.
    # <rails-lens:routes:begin>
    # ROUTE: /, name: mcp_get, via: GET
    # <rails-lens:routes:end>
    def show
      # MCP Streamable HTTP spec allows servers to return 405 if they don't support SSE.
      # ActionMCP uses Tasks for async operations instead of SSE streaming.
      head :method_not_allowed
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

    # Checks if the Accept headers for POST are valid.
    def post_accept_headers_valid?
      request.accepts.any? { |type| type.to_s == "application/json" }
    end

    # Returns the appropriate error message for POST Accept header validation.
    def post_accept_headers_error_message
      "Client must accept 'application/json'"
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

      add_session_header = is_initialize_request && session_initially_missing && session.persisted?
      render_json_response(payload, session, add_session_header)
    end

    # Renders the JSON-RPC response as a JSON HTTP response.
    def render_json_response(payload, session, add_session_header)
      response.headers[MCP_SESSION_ID_HEADER] = session.id if add_session_header
      # Add MCP-Protocol-Version header if session has been initialized
      response.headers["MCP-Protocol-Version"] = session.protocol_version if session&.initialized?
      response.headers["Content-Type"] = "application/json"
      render json: payload, status: :ok
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
