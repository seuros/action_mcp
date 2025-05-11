require "test_helper"

class SessionManagementThroughToolsTest < ActionDispatch::IntegrationTest
  include app.routes.url_helpers

  def app
    ActionMCP::Engine
  end

  setup do
    @session = ActionMCP::Session.create!(initialized: true)
    @session.register_tool("add_session_tool")
  end

  test "can add tools to session through MCP protocol" do
    params = {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: {
        name: "add_session_tool",
        arguments: { tool_name: "calculate_sum" }
      }
    }

    post sse_in_path(session_id: @session.id), params: params
    assert_response :accepted

    # Verify tool was added
    @session.reload
    assert_includes @session.tool_registry, "calculate_sum"
  end
end
