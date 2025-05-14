# frozen_string_literal: true

# test/mcp/tools/boom_tool_test.rb
require "test_helper"

class BoomToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "always returns internal_error" do
    resp = BoomTool.new.call
    assert resp.error?
    assert_mcp_error_code(-32_603, resp)
  end
end
