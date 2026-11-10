# frozen_string_literal: true

require "test_helper"

class McpSpecValidationTest < ActionDispatch::IntegrationTest
  setup do
    # Ensure configuration is properly loaded before creating sessions
    ActionMCP.configuration.name = "ActionMCP Dummy"

    # Create session through the session store
    session_store = ActionMCP::Server.session_store
    @session = session_store.create_session(nil, {
                                              initialized: true,
                                              status: "initialized",
                                              protocol_version: "2025-11-25"
                                            })
    @session_id = @session.id
  end

  test "error responses follow JSON-RPC spec" do
    mcp_post("unknown_method", {}, id: "invalid-1", session_id: @session_id)

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
    mcp_post("tools/call", {
      name: "consent_required",
      arguments: { input: "test" }
    }, id: "consent-1", session_id: @session_id)

    body = response.parsed_body
    assert body["error"]
    assert_equal(-32_002, body["error"]["code"]) # consent_required
    assert_match(/Consent required/, body["error"]["message"])

    # Grant consent and retry
    @session.grant_consent("consent_required")
    ActionMCP::Server.session_store.save_session(@session)

    mcp_post("tools/call", {
      name: "consent_required",
      arguments: { input: "test" }
    }, id: "consent-2", session_id: @session_id)

    body = response.parsed_body

    # Verify successful tool execution after consent granted
    assert_equal "2.0", body["jsonrpc"]
    assert_equal "consent-2", body["id"]
    assert body["result"]

    # Verify tool response content
    assert_equal [ { "type" => "text", "text" => "Processed input: test" } ], body["result"]["content"]
  end

  test "GET returns 405 with Allow header per RFC 9110" do
    get "/"

    assert_response :method_not_allowed
    assert_equal "POST, DELETE", response.headers["Allow"]
  end
end
