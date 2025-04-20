# frozen_string_literal: true

require "test_helper"

class CallbackAbortToolTest < ActiveSupport::TestCase
  test "tool aborts and returns invalid_request error" do
    resp = AbortTool.new(value: "x").call
    assert resp.error?
    assert_equal(-32_600, resp.to_h[:code]) # invalid_request from Tool#mark_as_error!
    assert_equal [], resp.contents
  end
end
