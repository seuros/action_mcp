# frozen_string_literal: true

class CalculateSumToolTest < ActiveSupport::TestCase
  test "should calculate sum" do
    tool = CalculateSumTool.new(number1: 1, number2: 2)
    response = CalculateSumTool.logger.silence do
      tool.call
    end
    assert_equal({ content: [ { type: "text", text: "3.0" } ] }, response.to_h)
  end

  test "should fail the validation" do
    tool = CalculateSumTool.new(number1: 123, number2: 1)
    response = CalculateSumTool.logger.silence do
      tool.call
    end
    assert_equal({ code: -32_600, message: "Invalid input", data: [ "Number1 must be 100 or less" ] }, response.to_h)
  end
end
