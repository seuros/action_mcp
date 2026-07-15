# frozen_string_literal: true

# test/action_mcp/tools_registry_error_test.rb
require "test_helper"

class ToolsRegistryErrorTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "tool_call returns :invalid_params when tool not found" do
    resp = ActionMCP::ToolsRegistry.tool_call("no_such_tool", {})
    assert resp.error?
    assert_mcp_error_code(-32_602, resp) # invalid_params
  end

  test "tool_call returns a tool execution error when tool execution raises" do
    resp = ActionMCP::ToolsRegistry.tool_call("explosive", {})
    assert resp.error?
    assert_equal true, resp.to_h[:isError]
    assert_match(/kaboom/, resp.to_h.dig(:content, 0, :text))
  end
end
