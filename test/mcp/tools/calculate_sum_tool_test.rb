# frozen_string_literal: true

require "test_helper"

class CalculateSumToolTest < ActiveSupport::TestCase
  test "should calculate sum" do
    tool = CalculateSumTool.new(a: 1, b: 2)
    response = tool.call
    assert_equal({ content: [ { type: "text", text: "3.0" } ] }, response.to_h)
  end

  test "should fail the validation" do
    tool = CalculateSumTool.new(a: 123, b: 1)
    response = tool.call
    assert_equal(
      { isError: true, content: [ { type: "text", text: "Invalid input: A must be 100 or less" } ] },
      response.to_h
    )
  end
end
