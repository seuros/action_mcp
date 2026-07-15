# frozen_string_literal: true

module ActionMCP
  # Implements the MCP endpoints according to the 2025-11-25 specification.
  # POST returns one JSON message, DELETE terminates sessions, and GET returns
  # 405 because the built-in transport does not provide SSE streams.
  class ApplicationController < ActionController::API
    MCP_SESSION_ID_HEADER = "Mcp-Session-Id"
    POST_ACCEPT_MEDIA_TYPES = %w[application/json text/event-stream].freeze

    include Engine.routes.url_helpers
    include JSONRPC_Rails::ControllerHelpers
    include ActionController::Instrumentation

    # Origin validation is enforced by ActionMCP::Middleware::OriginValidation
    # (see engine.rb) so invalid requests are rejected before routing.

    # Provides the ActionMCP::Session for the current request.
    # @return [ActionMCP::Session, nil] The session identified by the request header.
    def mcp_session
      return @mcp_session if defined?(@mcp_session)

      @mcp_session = load_session(extract_session_id)
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
      return unless authenticate_gateway!

      if (session_id = extract_session_id)
        session = load_session(session_id)
        return render_not_found("Session not found.") unless session
        return render_not_found("Session has been terminated.") if session.status == "closed"

        @mcp_session = session
        return unless configure_gateway_session!(session)
        return unless validate_protocol_version_header(session)
      end

      # MCP Streamable HTTP spec allows servers to return 405 if they don't support SSE.
      # ActionMCP uses Tasks for async operations instead of SSE streaming.
      response.headers["Allow"] = "POST, DELETE"
      head :method_not_allowed
    end

    # Handles POST requests containing one client JSON-RPC message.
    # <rails-lens:routes:begin>
    # ROUTE: /, name: mcp_post, via: POST
    # <rails-lens:routes:end>
    def create
      unless post_accept_headers_valid?
        id = extract_jsonrpc_id_from_request
        return render_not_acceptable(post_accept_headers_error_message, id)
      end

      payload = jsonrpc_params
      is_initialize_request = initialize_request?(payload)
      session_id = extract_session_id

      return unless authenticate_gateway!

      if (validation_error = ProtocolValidator.client_message_validation_error(payload))
        if payload.is_a?(JSON_RPC::Notification)
          return render_notification_error(validation_error)
        end

        return render_jsonrpc_error(validation_error.code, validation_error.message, request_id(payload))
      end

      session = if is_initialize_request
                  if session_id
                    existing_session = load_session(session_id)
                    return render_not_found("Session not found.", request_id(payload)) unless existing_session
                    if existing_session.status == "closed"
                      return render_not_found("Session has been terminated.", request_id(payload))
                    end

                    return render_bad_request("Initialize requests must not include an Mcp-Session-Id header.", request_id(payload))
                  end

                  create_session
      else
                  return render_bad_request("Mcp-Session-Id header is required for this request.", request_id(payload)) unless session_id

                  existing_session = load_session(session_id)
                  return render_not_found("Session not found.", request_id(payload)) unless existing_session
                  if existing_session.status == "closed"
                    return render_not_found("Session has been terminated.", request_id(payload))
                  end

                  existing_session
      end

      @mcp_session = session
      unless configure_gateway_session!(session)
        Server.session_store.delete_session(session.id) if is_initialize_request
        return
      end
      return unless is_initialize_request || validate_protocol_version_header(session)
      return unless lifecycle_allows?(payload, session, is_initialize_request)

      # Use return mode for the transport handler when we need to capture responses
      transport_handler = Server::TransportHandler.new(session, messaging_mode: :return)
      json_rpc_handler = Server::JsonRpcHandler.new(transport_handler)

      result = json_rpc_handler.call(jsonrpc_params)
      process_handler_results(result, session, is_initialize_request)
    rescue StandardError => e
      Server.session_store.delete_session(session.id) if is_initialize_request && session
      Rails.error.report(e, handled: true, severity: :error)
      id = begin
        jsonrpc_params.respond_to?(:id) ? jsonrpc_params.id : nil
      rescue StandardError
        nil
      end
      render_internal_server_error("An unexpected error occurred.", id) unless performed?
    end

    # Handles DELETE requests for session termination.
    # <rails-lens:routes:begin>
    # ROUTE: /, name: mcp_delete, via: DELETE
    # <rails-lens:routes:end>
    def destroy
      return unless authenticate_gateway!

      session_id_from_header = extract_session_id
      return render_bad_request("Mcp-Session-Id header is required for DELETE requests.") unless session_id_from_header

      session = load_session(session_id_from_header)
      if session.nil?
        return render_not_found("Session not found.")
      elsif session.status == "closed"
        return render_not_found("Session has been terminated.")
      end

      @mcp_session = session
      return unless configure_gateway_session!(session)
      return unless validate_protocol_version_header(session)

      begin
        session.close!
        Rails.logger.info "Unified DELETE: Terminated session: #{session.id}" if ActionMCP.configuration.verbose_logging
        head :no_content
      rescue StandardError => e
        Rails.error.report(e, handled: true, severity: :error)
        render_internal_server_error("Failed to terminate session.")
      end
    end

    private

    # Validates the MCP-Protocol-Version header for requests after initialization.
    # Returns true if valid, renders error and returns false if invalid
    def validate_protocol_version_header(session)
      header_version = request.headers["MCP-Protocol-Version"] || request.headers["mcp-protocol-version"]
      return true if header_version.nil? && session.protocol_version == ActionMCP::LATEST_VERSION

      header_version = header_version.last if header_version.is_a?(Array)

      # Check if the header version is supported
      unless ActionMCP::SUPPORTED_VERSIONS.include?(header_version)
        supported_versions = ActionMCP::SUPPORTED_VERSIONS.join(", ")
        ActionMCP.logger.warn "Unsupported MCP-Protocol-Version: #{header_version}. Supported versions: #{supported_versions}"
        render_protocol_version_error("Unsupported MCP-Protocol-Version: #{header_version}. Supported versions: #{supported_versions}")
        return false
      end

      negotiated_version = session.protocol_version
      if header_version != negotiated_version
        ActionMCP.logger.warn "MCP-Protocol-Version mismatch: header=#{header_version}, negotiated=#{negotiated_version}"
        render_protocol_version_error("MCP-Protocol-Version header (#{header_version}) does not match negotiated version (#{negotiated_version})")
        return false
      end

      true
    end

    def load_session(session_id)
      return unless session_id

      ActionMCP::Server.session_store.load_session(session_id)
    end

    def create_session
      ActionMCP::Server.session_store.create_session(
        nil,
        protocol_version: ActionMCP::DEFAULT_PROTOCOL_VERSION
      )
    end

    # @return [String, nil] The extracted session ID or nil if not found.
    def extract_session_id
      request.headers[MCP_SESSION_ID_HEADER].presence
    end

    # Checks if the Accept headers for POST are valid.
    def post_accept_headers_valid?
      accepted_media_types = Rack::Utils.q_values(request.get_header("HTTP_ACCEPT")).filter_map do |media_range, quality|
        Rack::MediaType.type(media_range)&.downcase if quality.positive?
      end

      POST_ACCEPT_MEDIA_TYPES.all? { |media_type| accepted_media_types.include?(media_type) }
    end

    # Returns the appropriate error message for POST Accept header validation.
    def post_accept_headers_error_message
      "Not Acceptable: Client must accept both application/json and text/event-stream"
    end

    def initialize_request?(payload)
      payload.is_a?(JSON_RPC::Request) && payload.method == JsonRpcHandlerBase::Methods::INITIALIZE
    end

    def initialized_notification?(payload)
      payload.is_a?(JSON_RPC::Notification) &&
        payload.method == JsonRpcHandlerBase::Methods::NOTIFICATIONS_INITIALIZED
    end

    def ping_request?(payload)
      payload.is_a?(JSON_RPC::Request) && payload.method == JsonRpcHandlerBase::Methods::PING
    end

    def lifecycle_allows?(payload, session, initialize_request)
      return true if initialize_request

      if initialized_notification?(payload)
        return true if session.status == "initializing" && !session.initialized?

        render_bad_request("Session is not awaiting an initialized notification.", request_id(payload))
        return false
      end

      return true if session.initialized?
      return true if session.status == "initializing" && ping_request?(payload)

      render_bad_request("Session initialization is incomplete.", request_id(payload))
      false
    end

    # Processes the results from the JsonRpcHandler.
    def process_handler_results(result, session, is_initialize_request)
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

      successful_initialize = is_initialize_request && result.is_a?(JSON_RPC::Response) && result.error.nil?
      Server.session_store.delete_session(session.id) if is_initialize_request && !successful_initialize

      add_session_header = successful_initialize && session.persisted?
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
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_600, message: message } }, status: :bad_request
    end

    # Renders a 400 Bad Request response for protocol version errors as per MCP spec
    def render_protocol_version_error(message = "Protocol Version Error", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_000, message: message } }, status: :bad_request
    end

    # Renders a 404 Not Found response with a JSON-RPC-like error structure.
    def render_not_found(message = "Not Found", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_001, message: message } }, status: :not_found
    end

    # Renders a 405 Method Not Allowed response.
    def render_method_not_allowed(message = "Method Not Allowed", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_601, message: message } }, status: :method_not_allowed
    end

    # Renders a 406 Not Acceptable response.
    def render_not_acceptable(message = "Not Acceptable", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_000, message: message } }, status: :not_acceptable
    end

    # Renders a 501 Not Implemented response.
    def render_not_implemented(message = "Not Implemented", id = nil)
      id ||= extract_jsonrpc_id_from_request
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_003, message: message } }, status: :not_implemented
    end

    # Renders a 500 Internal Server Error response.
    def render_internal_server_error(message = "Internal Server Error", id = nil)
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_603, message: message } }, status: :internal_server_error
    end

    def render_jsonrpc_error(symbol, message, id = nil)
      error = JSON_RPC::JsonRpcError.new(symbol, message: message)
      render json: JSON_RPC::Response.new(id: id, error: error), status: :ok
    end

    def render_notification_error(validation_error)
      error = JSON_RPC::JsonRpcError.new(validation_error.code, message: validation_error.message)
      render json: JSON_RPC::Response.new(id: nil, error: error), status: :bad_request
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

    def request_id(payload)
      payload.respond_to?(:id) ? payload.id : nil
    end

    # Authenticates the request using the configured gateway
    def authenticate_gateway!
      gateway_class = ActionMCP.configuration.gateway_class
      return true unless gateway_class

      begin
        @authenticated_gateway = gateway_class.new(request)
        @authenticated_gateway.call
        true
      rescue ActionMCP::UnauthorizedError => e
        render_unauthorized(e.message)
        false
      rescue StandardError => e
        Rails.error.report(e, handled: true, severity: :error)
        render_unauthorized("Authentication system error")
        false
      end
    end

    def configure_gateway_session!(session)
      return true unless @authenticated_gateway

      @authenticated_gateway.configure_session(session)
      true
    rescue ActionMCP::UnauthorizedError => e
      render_unauthorized(e.message)
      false
    rescue StandardError => e
      Rails.error.report(e, handled: true, severity: :error)
      render_unauthorized("Authentication system error")
      false
    end

    # Renders an unauthorized response
    def render_unauthorized(message = "Unauthorized", id = nil)
      id ||= extract_jsonrpc_id_from_request

      challenge = "Bearer"
      challenge += ' error="invalid_token"' if request.headers["Authorization"].present?
      response.headers["WWW-Authenticate"] = challenge
      render json: { jsonrpc: "2.0", id: id, error: { code: -32_000, message: message } }, status: :unauthorized
    end
  end
end
