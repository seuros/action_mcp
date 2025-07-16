# frozen_string_literal: true

require "test_helper"

class McpSpecValidationTest < ActionDispatch::IntegrationTest
  setup do
    # Ensure configuration is properly loaded before creating sessions
    ActionMCP.configuration.name = "ActionMCP Dummy"

    # Create session through the session store
    session_store = ActionMCP::Server.session_store
    @session = session_store.create_session(nil, {
                                              initialized: false,
                                              protocol_version: ActionMCP::DEFAULT_PROTOCOL_VERSION
                                            })
    @session_id = @session.id
  end

  test "initialization follows MCP spec" do
    post "/", params: {
      jsonrpc: "2.0",
      id: "init-1",
      method: "initialize",
      params: {
        protocolVersion: "2025-03-26",
        clientInfo: { name: "Test Client", version: "1.0" },
        capabilities: {
          roots: { listChanged: true },
          sampling: {}
        }
      }
    }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json", "Mcp-Session-Id" => @session_id }

    assert_response :success
    body = response.parsed_body

    # Verify JSON-RPC response structure
    assert_equal "2.0", body["jsonrpc"]
    assert_equal "init-1", body["id"]
    assert body["result"]

    # Verify MCP protocol version matches request
    assert_equal "2025-03-26", body["result"]["protocolVersion"]

    # Verify server info contains expected values
    assert_equal "ActionMCP Dummy", body["result"]["serverInfo"]["name"]
    assert_equal "9.9.9", body["result"]["serverInfo"]["version"]

    # Verify capabilities structure matches expected server capabilities
    expected_capabilities = {
      "tools" => { "listChanged" => true },
      "prompts" => { "listChanged" => true },
      "logging" => {},
      "resources" => { "subscribe" => false, "listChanged" => true }
    }
    assert_equal expected_capabilities, body["result"]["capabilities"]
  end

  test "error responses follow JSON-RPC spec" do
    post "/", params: {
      jsonrpc: "2.0",
      id: "invalid-1",
      method: "unknown_method",
      params: {}
    }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json", "Mcp-Session-Id" => @session_id }

    assert_response :success
    body = response.parsed_body
    assert body["error"]
    assert_equal(-32_601, body["error"]["code"]) # method_not_found
  end

  test "consent flow matches MCP draft" do
    # Register tool in the session from the store
    @session.register_tool(ConsentRequiredTool)
    ActionMCP::Server.session_store.save_session(@session)

    # Without consent
    post "/", params: {
      jsonrpc: "2.0",
      id: "consent-1",
      method: "tools/call",
      params: {
        name: "consent_required",
        arguments: { input: "test" }
      }
    }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json", "Mcp-Session-Id" => @session_id }

    body = response.parsed_body
    assert body["error"]
    assert_equal(-32_002, body["error"]["code"]) # consent_required
    assert_match(/Consent required/, body["error"]["message"])

    # Grant consent and retry
    @session.grant_consent("consent_required")
    ActionMCP::Server.session_store.save_session(@session)

    post "/", params: {
      jsonrpc: "2.0",
      id: "consent-2",
      method: "tools/call",
      params: {
        name: "consent_required",
        arguments: { input: "test" }
      }
    }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json", "Mcp-Session-Id" => @session_id }

    body = response.parsed_body

    # Verify successful tool execution after consent granted
    assert_equal "2.0", body["jsonrpc"]
    assert_equal "consent-2", body["id"]
    assert body["result"]

    # Verify tool response content
    assert_equal [ { "type" => "text", "text" => "Processed input: test" } ], body["result"]["content"]
  end
end
