# frozen_string_literal: true

require "test_helper"

class ToolConsentTest < ActionDispatch::IntegrationTest
  fixtures :action_mcp_sessions

  setup do
    ActionMCP::ToolsRegistry.register(ConsentRequiredTool)
    @session = action_mcp_sessions(:test_session)
    @session_id = @session.id

    # Set server capabilities and tool registry
    @session.update!(
      server_capabilities: {
        "tools" => {
          "listChanged" => true
        }
      },
      tool_registry: [ "consent_required" ]
    )

    # Ensure session is in the session store with tool registry
    ActionMCP::Server.session_store.create_session(@session_id, {
                                                     initialized: false,
                                                     status: "pre_initialize",
                                                     role: "server",
                                                     tool_registry: [ "consent_required" ]
                                                   })

    post "/", params: {
      jsonrpc: "2.0",
      id: "init-1",
      method: "initialize",
      params: {
        protocolVersion: "2025-06-18",
        clientInfo: { name: "Test Client", version: "1.0" },
        capabilities: { tools: { dynamicRegistration: true } }
      }
    }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream", "Mcp-Session-Id" => @session_id }
    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    @session.reload
    @session.register_tool(ConsentRequiredTool)
    @session.save!
  end

  test "tool requires consent" do
    post "/", params: {
      jsonrpc: "2.0",
      id: "test-1",
      method: "tools/call",
      params: {
        name: "consent_required",
        arguments: { input: "test" }
      }
    }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream", "Mcp-Session-Id" => @session_id }

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

    post "/", params: {
      jsonrpc: "2.0",
      id: "test-2",
      method: "tools/call",
      params: {
        name: "consent_required",
        arguments: { input: "test" }
      }
    }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream", "Mcp-Session-Id" => @session_id }

    assert_response :success
    body = response.parsed_body
    assert body["result"], "Expected result in response, got: #{body.inspect}"
    assert_equal [ { "type" => "text", "text" => "Processed input: test" } ], body["result"]["content"]
  end
end
