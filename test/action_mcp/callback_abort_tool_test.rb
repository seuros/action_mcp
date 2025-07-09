# frozen_string_literal: true

require "test_helper"

class CallbackAbortToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper
  test "tool aborts and returns invalid_request error" do
    resp = AbortTool.new(value: "x").call
    assert resp.error?
    assert_mcp_error_code(-32_602, resp) # invalid_request from Tool#mark_as_error!
    assert_equal [], resp.contents
  end
end
