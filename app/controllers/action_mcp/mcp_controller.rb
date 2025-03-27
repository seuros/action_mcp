# frozen_string_literal: true

module ActionMCP
  class MCPController < ActionController::Metal
    abstract!
    ActionController::API.without_modules(:StrongParameters, :ParamsWrapper).each do |left|
      include left
    end
    include Engine.routes.url_helpers

    # Header name for MCP Session ID (as per 2025-03-26 spec)
    MCP_SESSION_ID_HEADER = "Mcp-Session-Id"

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

    private

    # Finds an existing session based on header or param, or initializes a new one.
    # Note: This doesn't save the new session; that happens upon first use or explicitly.
    def find_or_initialize_session
      session_id = extract_session_id
      if session_id
        # Attempt to find the session by ID. Return nil if not found.
        # Controllers should handle the nil case (e.g., return 404).
        Session.find_by(id: session_id)
      else
        # No session ID provided, initialize a new one (likely for 'initialize' request).
        Session.new
      end
    end

    # Extracts the session ID from the request header or parameters.
    # Prefers the Mcp-Session-Id header (new spec) over the param (old spec).
    # @return [String, nil] The extracted session ID or nil if not found.
    def extract_session_id
      request.headers[MCP_SESSION_ID_HEADER].presence || params[:session_id].presence
    end

    # Renders a 400 Bad Request response with a JSON-RPC-like error structure.
    def render_bad_request(message = "Bad Request")
      # Using -32600 for Invalid Request based on JSON-RPC spec
      render json: { jsonrpc: "2.0", error: { code: -32_600, message: message } }, status: :bad_request
    end

    # Renders a 404 Not Found response with a JSON-RPC-like error structure.
    def render_not_found(message = "Not Found")
      # Using a custom code or a generic server error range code might be appropriate.
      # Let's use -32001 for a generic server error.
      render json: { jsonrpc: "2.0", error: { code: -32_001, message: message } }, status: :not_found
    end

    # Renders a 405 Method Not Allowed response.
    def render_method_not_allowed(message = "Method Not Allowed")
      # Using -32601 Method not found from JSON-RPC spec seems applicable
      render json: { jsonrpc: "2.0", error: { code: -32_601, message: message } }, status: :method_not_allowed
    end

    # Renders a 406 Not Acceptable response.
    def render_not_acceptable(message = "Not Acceptable")
      # No direct JSON-RPC equivalent, using a generic server error code.
      render json: { jsonrpc: "2.0", error: { code: -32_002, message: message } }, status: :not_acceptable
    end

    # Renders a 501 Not Implemented response.
    def render_not_implemented(message = "Not Implemented")
      # No direct JSON-RPC equivalent, using a generic server error code.
      render json: { jsonrpc: "2.0", error: { code: -32_003, message: message } }, status: :not_implemented
    end
  end
end
