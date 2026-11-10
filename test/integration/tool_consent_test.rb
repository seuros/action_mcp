# frozen_string_literal: true

require "test_helper"

class ToolConsentTest < ActionDispatch::IntegrationTest
  fixtures :action_mcp_sessions

  setup do
    ActionMCP::ToolsRegistry.register(ConsentRequiredTool)

    mcp_post("initialize", {
      protocolVersion: "2025-11-25",
      clientInfo: { name: "Test Client", version: "1.0" },
      capabilities: { tools: { dynamicRegistration: true } }
    }, id: "init-1")
    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"

    @session_id = response.headers["Mcp-Session-Id"]
    assert @session_id.present?

    @session = ActionMCP::Server.session_store.load_session(@session_id)
    @session.update!(tool_registry: [ "consent_required" ])

    mcp_notify("notifications/initialized", session_id: @session_id)
    assert_response :accepted
  end

  test "tool requires consent" do
    mcp_post("tools/call", {
      name: "consent_required",
      arguments: { input: "test" }
    }, id: "test-1", session_id: @session_id)

    assert_response :success
    body = response.parsed_body
    assert body["error"]
    assert_equal(-32_002, body["error"]["code"])
    assert_match(/Consent required/, body["error"]["message"])
  end

  test "tool executes after granting consent" do
    # Grant consent on the session in the session store
    session_in_store = ActionMCP::Server.session_store.load_session(@session_id)
    session_in_store.grant_consent("consent_required")

    # Also update the ActiveRecord session to keep them in sync
    @session.grant_consent("consent_required")
    @session.save!

    mcp_post("tools/call", {
      name: "consent_required",
      arguments: { input: "test" }
    }, id: "test-2", session_id: @session_id)

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    assert_equal [ { "type" => "text", "text" => "Processed input: test" } ], body["result"]["content"]
  end
end
