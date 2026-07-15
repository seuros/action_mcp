# frozen_string_literal: true

require "test_helper"

class CallbackAbortToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper
  test "tool aborts and returns a tool execution error" do
    resp = AbortTool.new(value: "x").call
    assert resp.error?
    assert_equal true, resp.to_h[:isError]
    assert_match(/execution was aborted/, resp.contents.first.text)
  end
end
