# frozen_string_literal: true

require "test_helper"

class DebugErrorCodeTest < ActionDispatch::IntegrationTest
  fixtures :action_mcp_sessions

  setup do
    @session = action_mcp_sessions(:test_session)

    # Ensure session is in the session store
    store = ActionMCP::Server.session_store
    store.save_session(@session)
    store.load_session(@session.id)
  end

  test "debug error code for unknown method" do
    post "/", params: {
      jsonrpc: "2.0",
      id: "test-1",
      method: "unknown_method",
      params: {}
    }.to_json, headers: {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "Mcp-Session-Id" => @session.id
    }

    assert_response :success
    body = response.parsed_body

    # Verify JSON-RPC error response structure
    assert_equal "2.0", body["jsonrpc"]
    assert_equal "test-1", body["id"]
    assert body["error"], "Expected error response for unknown method"

    # Verify error code is method_not_found per JSON-RPC spec
    assert_equal(-32_601, body["error"]["code"])
    assert_match(/method not found/i, body["error"]["message"].downcase)
  end
end
