# frozen_string_literal: true

require "test_helper"

class DebugInitTest < ActionDispatch::IntegrationTest
  setup do
    # Ensure configuration is properly loaded before creating sessions
    ActionMCP.configuration.name = "ActionMCP Dummy"
    ActionMCP.configuration.load_profiles

    # Create session through the session store (since this is testing initialization)
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
        protocolVersion: "2025-06-18",
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
    assert body["result"], "Expected result but got: #{body.inspect}"

    # Verify MCP protocol version matches request
    assert_equal "2025-06-18", body["result"]["protocolVersion"]

    # Verify server info contains expected values
    assert_equal "ActionMCP Dummy", body["result"]["serverInfo"]["name"]
    assert_equal "9.9.9", body["result"]["serverInfo"]["version"]

    # Verify capabilities structure matches expected server capabilities
    expected_capabilities = {
      "tools" => { "listChanged" => true },
      "prompts" => { "listChanged" => true },
      "resources" => { "subscribe" => false, "listChanged" => true }
    }
    assert_equal expected_capabilities, body["result"]["capabilities"]
  end
end
