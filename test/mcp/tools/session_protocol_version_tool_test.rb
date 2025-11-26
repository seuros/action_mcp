# frozen_string_literal: true

require "test_helper"

class SessionProtocolVersionToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper
  fixtures :action_mcp_sessions

  def setup
    @tool = SessionProtocolVersionTool.new
  end

  test "returns protocol version for Dr. Identity McBouncer session" do
    # Create a session with 2025-06-18 protocol
    session = action_mcp_sessions(:dr_identity_mcbouncer_session)
    session.update!(
      id: "test-session-2025-06-18",
      protocol_version: "2025-06-18",
      initialized: true,
      status: "initialized"
    )

    @tool.with_context({ session: session })

    result = @tool.call

    assert result.success?
    assert_equal 1, result.contents.size

    content = result.contents.first
    assert_equal "text", content.type

    response_data = JSON.parse(content.text)
    assert_equal "2025-06-18", response_data["protocol_version"]
    assert_equal "Dr. Identity McBouncer", response_data["codename"]
    assert_equal session.id, response_data["session_id"]
    assert_includes response_data["supported_versions"], "2025-11-25"
    assert_includes response_data["supported_versions"], "2025-06-18"
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
  end

  test "handles unknown protocol version" do
    # Skip this test since ActionMCP validates protocol versions
    # and won't allow creating sessions with unknown protocol versions
    skip "ActionMCP validates protocol versions during session creation"
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
