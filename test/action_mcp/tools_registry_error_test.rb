# frozen_string_literal: true

# test/action_mcp/tools_registry_error_test.rb
require "test_helper"

class ToolsRegistryErrorTest < ActiveSupport::TestCase
  test "tool_call returns :invalid_params when tool not found" do
    resp = ActionMCP::ToolsRegistry.tool_call("no_such_tool", {})
    assert resp.error?
    assert_equal(-32_602, resp.to_h[:code])          # invalid_params
  end



  test "tool_call surfaces :internal_error when tool itself raises" do
    resp = ActionMCP::ToolsRegistry.tool_call("explosive", {})
    assert resp.error?
    assert_equal(-32_603, resp.to_h[:code])          # internal_error
    assert_match(/kaboom/, resp.to_h[:message])
  end
end
