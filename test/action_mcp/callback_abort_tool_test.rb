# frozen_string_literal: true

require "test_helper"

# A tool that aborts in before_perform so perform never runs
class AbortTool < ApplicationMCPTool
  description "Demonstrates throw(:abort) inside callbacks"
  property :value, type: "string"

  before_perform { throw :abort }

  def perform
    render text: "should never appear"
  end
end

class CallbackAbortToolTest < ActiveSupport::TestCase
  test "tool aborts and returns invalid_request error" do
    resp = AbortTool.new(value: "x").call
    assert resp.error?
    assert_equal(-32_600, resp.to_h[:code]) # invalid_request from Tool#mark_as_error!
    assert_equal [], resp.contents
  end
end
