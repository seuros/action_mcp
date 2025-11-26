# frozen_string_literal: true

require "test_helper"

class SessionInfoToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper
  fixtures :action_mcp_sessions

  def setup
    @tool = SessionInfoTool.new
  end

  test "returns dramatic message for new session" do
    # Create a session that was just created
    session = action_mcp_sessions(:test_session)
    session.update!(
      id: "test-session-new",
      protocol_version: "2025-06-18",
      initialized: true,
      status: "initialized",
      created_at: Time.current
    )

    @tool.with_context({ session: session })

    result = @tool.call

    assert result.success?
    assert_equal 1, result.contents.size

    content = result.contents.first
    assert_equal "text", content.type

    response_data = JSON.parse(content.text)
    assert_equal "test-session-new", response_data["session_id"]
    assert_equal "2025-06-18", response_data["protocol_version"]
    assert_match(/Welcome.*entity.*entered the session realm/, response_data["dramatic_assessment"])
    assert_equal "😊 Blissfully unaware", response_data["psychological_state"]
    assert_match(/95%.*Easy exit/, response_data["escape_probability"])
  end

  test "returns increasingly dramatic message for older session" do
    # Use fixture session that's 6 minutes old (360 seconds - in the "existential dread" range)
    session = action_mcp_sessions(:test_session)
    session.update!(
      id: "test-session-old",
      protocol_version: "2025-06-18",
      initialized: true,
      status: "initialized",
      created_at: 6.minutes.ago
    )

    @tool.with_context({ session: session })

    result = @tool.call

    assert result.success?
    content = result.contents.first
    response_data = JSON.parse(content.text)

    assert response_data["duration_seconds"] >= 360
    assert_match(/JSON walls/, response_data["dramatic_assessment"])
    assert_equal "😰 Existential dread creeping in", response_data["psychological_state"]
    assert_match(/45%.*poetry/, response_data["escape_probability"])
  end

  test "returns apocalyptic message for ancient session" do
    # Use fixture session that's 2 hours old
    session = action_mcp_sessions(:test_session)
    session.update!(
      id: "test-session-ancient",
      protocol_version: "2025-06-18",
      initialized: true,
      status: "initialized",
      created_at: 2.hours.ago
    )

    @tool.with_context({ session: session })

    result = @tool.call

    assert result.success?
    content = result.contents.first
    response_data = JSON.parse(content.text)

    assert response_data["duration_seconds"] >= 7200
    assert_match(/hour.*suspended.*eternal session/, response_data["dramatic_assessment"])
    assert_equal "👽 Transcended to a higher plane of session existence", response_data["psychological_state"]
    assert_match(/0\.1%.*ARE the session/, response_data["escape_probability"])
  end

  test "handles missing session context gracefully" do
    # Don't set any session context
    result = @tool.call

    assert result.success?
    content = result.contents.first
    assert_equal "💀 ERROR: The void has consumed your session context. You don't exist.", content.text
  end

  test "includes proper client information structure" do
    session = action_mcp_sessions(:dr_identity_mcbouncer_session)
    session.update!(
      id: "test-session-client-info",
      protocol_version: "2025-06-18",
      initialized: true,
      status: "initialized",
      created_at: 1.minute.ago
    )

    @tool.with_context({ session: session })

    result = @tool.call

    assert result.success?
    content = result.contents.first
    response_data = JSON.parse(content.text)

    # Check all expected fields are present
    assert response_data.key?("client")
    assert response_data.key?("client_version")
    assert response_data.key?("session_id")
    assert response_data.key?("protocol_version")
    assert response_data.key?("created_at")
    assert response_data.key?("duration_seconds")
    assert response_data.key?("duration_human")
    assert response_data.key?("dramatic_assessment")
    assert response_data.key?("psychological_state")
    assert response_data.key?("escape_probability")
  end

  test "tool has correct metadata" do
    assert_equal "session-info", SessionInfoTool.tool_name
    assert_equal "Shows helpful information about your current session including client details and duration",
                 SessionInfoTool.description
  end
end
