# frozen_string_literal: true

# test/mcp/tools/boom_tool_test.rb
require "test_helper"

class BoomToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "always returns a tool execution error" do
    resp = BoomTool.new.call
    assert resp.error?
    assert_equal true, resp.to_h[:isError]
    assert_match(/Simulated failure/, resp.contents.first.text)
  end
end
