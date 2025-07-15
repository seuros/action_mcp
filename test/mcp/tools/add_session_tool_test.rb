# frozen_string_literal: true

require "test_helper"

class AddSessionToolTest < ActiveSupport::TestCase
  fixtures :action_mcp_sessions

  setup do
    @session = action_mcp_sessions(:test_session)
    # Override default wildcard registry for testing
    @session.update!(
      tool_registry: [],
      server_capabilities: ActionMCP.configuration.capabilities
    )
    # Register the meta-tool itself
    @session.register_tool("add_session")
  end

  test "adds a tool to the current session using execution context" do
    tool = AddSessionTool.new(tool_name: "calculate_sum")
    tool.with_context(session: @session)

    result = tool.call

    assert result.success?
    assert_includes result.contents.first.text, "successfully added"
    assert_includes @session.tool_registry, "calculate_sum"
    assert(@session.registered_tools.any? { |t| t.tool_name == "calculate_sum" })
  end

  test "handles non-existent tool gracefully" do
    tool = AddSessionTool.new(tool_name: "non_existent_tool")
    tool.with_context(session: @session)

    result = tool.call

    assert result.success?
    assert_includes result.contents.first.text, "not found"
    refute_includes @session.tool_registry, "non_existent_tool"
  end

  test "handles missing session context" do
    tool = AddSessionTool.new(tool_name: "calculate_sum")
    # Don't set context

    result = tool.call

    assert result.success?
    assert_includes result.contents.first.text, "No session context"
  end

  test "shows updated tool list after adding" do
    # Add an initial tool
    @session.register_tool("calculate_sum")

    tool = AddSessionTool.new(tool_name: "weather_forecast")
    tool.with_context(session: @session)

    result = tool.call

    assert result.success?
    # Check that the response shows all tools
    response_text = result.contents.map(&:text).join(" ")
    # The tool should show all three registered tools
    assert_includes response_text, "calculate_sum"
    assert_includes response_text, "weather_forecast"
    assert_includes response_text, "add_session"

    # Also verify the session actually has all tools registered
    @session.reload
    assert_equal 3, @session.tool_registry.size
    assert_includes @session.tool_registry, "calculate_sum"
    assert_includes @session.tool_registry, "weather_forecast"
    assert_includes @session.tool_registry, "add_session"
  end
end
