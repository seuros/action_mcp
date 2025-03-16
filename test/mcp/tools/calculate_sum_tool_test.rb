# frozen_string_literal: true

class CalculateSumToolTest < ActiveSupport::TestCase
  test "should calculate sum" do
    tool = CalculateSumTool.new(a: 1, b: 2)
    response = tool.call
    assert_equal({ content: [ { "type" => "text", "text" => "3.0" } ], isError: false }, response.to_h)
  end

  test "should accept just number" do
    tool = CalculateSumTool.new(a: 123, b: 1)
    response = tool.call
    assert_equal({ content: [ { "type" => "text", "text" => "Invalid input: A must be 100 or less" } ], isError: true }, response.to_h)
  end
end
