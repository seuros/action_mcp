# frozen_string_literal: true

require "test_helper"

class SessionManagementThroughToolsTest < ActionDispatch::IntegrationTest
  include app.routes.url_helpers

  def app
    ActionMCP::Engine
  end

  setup do
    # Create session through the proper session store
    session_store = ActionMCP::Server.session_store
    @session = session_store.create_session(
      SecureRandom.hex(6),
      protocol_version: "2025-06-18",
      initialized: true,
      status: "initialized"
    )
    # Override default wildcard registry for this specific test
    @session.tool_registry = []
    @session.save!
    @session.register_tool("add_session")
  end

  test "can add tools to session through MCP protocol" do
    params = {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: {
        name: "add_session",
        arguments: { tool_name: "calculate_sum" }
      }
    }

    post "/",
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream",
           "Mcp-Session-Id" => @session.id
         },
         params: params.to_json
    assert_includes [ 200, 202 ], response.status

    # Check response is successful
    response_json = JSON.parse(response.body)
    assert_nil response_json["error"], "Expected no error but got: #{response_json['error']}"

    # Verify tool was added
    @session.reload
    assert_includes @session.tool_registry, "calculate_sum"
  end
end
