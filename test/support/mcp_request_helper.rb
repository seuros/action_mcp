# frozen_string_literal: true

# JSON-RPC over Streamable HTTP for integration tests.
module MCPRequestHelper
  MCP_ACCEPT = "application/json, text/event-stream"

  def mcp_request_headers(session_id: nil, protocol_version: nil, **extra)
    headers = { "Content-Type" => "application/json", "Accept" => MCP_ACCEPT }
    headers["Mcp-Session-Id"] = session_id if session_id
    headers["MCP-Protocol-Version"] = protocol_version if protocol_version
    headers.merge(extra)
  end

  # Posts a JSON-RPC request; id: nil makes it a notification.
  def mcp_post(method, params = nil, id: 1, **options)
    mcp_send({ jsonrpc: "2.0", id: id, method: method, params: params }.compact, **options)
  end

  # Posts a complete JSON-RPC payload (request, notification, response or batch).
  def mcp_send(payload, path: "/", session_id: nil, protocol_version: nil, headers: {})
    post path,
         params: payload.to_json,
         headers: mcp_request_headers(session_id: session_id, protocol_version: protocol_version).merge(headers)
  end

  def mcp_notify(method, params = nil, **options)
    mcp_post(method, params, id: nil, **options)
  end

  def mcp_initialize_params(protocol_version: ActionMCP::LATEST_VERSION, client_name: "test", client_version: "1.0")
    {
      protocolVersion: protocol_version,
      capabilities: {},
      clientInfo: { name: client_name, version: client_version }
    }
  end

  # Runs initialize (and notifications/initialized unless complete: false); returns the session id.
  def initialize_mcp_session(path: "/", complete: true, **initialize_params)
    mcp_post("initialize", mcp_initialize_params(**initialize_params), id: "init-#{SecureRandom.hex(4)}", path: path)
    assert_response :ok
    session_id = response.headers["Mcp-Session-Id"]
    assert session_id.present?, "Expected Mcp-Session-Id in response headers"

    mcp_notify("notifications/initialized", path: path, session_id: session_id) if complete
    session_id
  end
end

ActionDispatch::IntegrationTest.include(MCPRequestHelper)
