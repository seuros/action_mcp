# frozen_string_literal: true

require "test_helper"

class ErrorHandlingTest < ActionDispatch::IntegrationTest
  setup do
    # Create session through the session store
    session_store = ActionMCP::Server.session_store
    @session = session_store.create_session(nil, {
                                              initialized: true,
                                              status: "initialized",
                                              protocol_version: "2025-11-25"
                                            })
    @session_id = @session.id

    # Register tool and save session
    @session.register_tool(ErrorRaisingTool)
    session_store.save_session(@session)
  end

  test "handles tool execution errors properly" do
    post "/", params: {
      jsonrpc: "2.0",
      id: "test-1",
      method: "tools/call",
      params: {
        name: "error_raising",
        arguments: { input: "test" }
      }
    }.to_json, headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream", "Mcp-Session-Id" => @session_id }

    assert_response :success
    body = response.parsed_body
    assert_equal true, body.dig("result", "isError")
    assert_equal "An unexpected error occurred.", body.dig("result", "content", 0, "text")
  end
end
