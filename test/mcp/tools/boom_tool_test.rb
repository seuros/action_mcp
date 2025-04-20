# frozen_string_literal: true

# test/mcp/tools/boom_tool_test.rb
require "test_helper"

class BoomToolTest < ActiveSupport::TestCase
  test "always returns internal_error" do
    resp = BoomTool.new.call
    assert resp.error?
    assert_equal(-32_603, resp.to_h[:code]) # -32603 internal_error
  end
end
