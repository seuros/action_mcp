# frozen_string_literal: true

require "test_helper"

class SessionProtocolVersionToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper
  fixtures :action_mcp_sessions

  def setup
    @tool = SessionProtocolVersionTool.new
  end

  test "returns protocol version for Task Master session" do
    # Use fixture session with 2025-11-25 protocol (The Task Master)
    session = action_mcp_sessions(:step1_session)
    session.update!(
      id: "test-session-2025-11-25",
      protocol_version: "2025-11-25",
      initialized: true,
      status: "initialized"
    )

    @tool.with_context({ session: session })

    result = @tool.call

    assert result.success?
    content = result.contents.first
    response_data = JSON.parse(content.text)

    assert_equal "2025-11-25", response_data["protocol_version"]
    assert_equal "The Task Master", response_data["codename"]
    assert_equal session.id, response_data["session_id"]
    assert_equal [ "2025-11-25" ], response_data["supported_versions"]
  end

  test "handles session not found error" do
    # Don't set any session context - this will trigger the error handling
    result = @tool.call

    assert result.success?
    content = result.contents.first
    assert_equal "Error: No session context available", content.text
  end

  test "tool has correct metadata" do
    assert_equal "session-protocol-version", SessionProtocolVersionTool.tool_name
    assert_equal "Returns the MCP protocol version being used in the current session",
                 SessionProtocolVersionTool.description
  end
end
