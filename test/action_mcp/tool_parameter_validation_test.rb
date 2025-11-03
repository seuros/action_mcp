# frozen_string_literal: true

require "test_helper"

class ActionMCP::ToolParameterValidationTest < ActiveSupport::TestCase
  test "rejects non-numeric parameter for number property" do
    error = assert_raises(ArgumentError) do
      AddTool.new(x: "not_a_number", y: 5)
    end

    assert_match(/must be a valid number/, error.message)
    assert_match(/not_a_number/, error.message)
  end

  test "rejects non-array parameter for collection property" do
    error = assert_raises(ArgumentError) do
      NumericArrayTool.new(numbers: "not_an_array")
    end

    assert_match(/must be an array/, error.message)
  end

  test "accepts valid numeric parameters" do
    tool = AddTool.new(x: 3.14, y: 2.71)

    assert tool.valid?
    assert_equal 3.14, tool.x
    assert_equal 2.71, tool.y
  end

  test "accepts string convertible to number" do
    tool = AddTool.new(x: "3.14", y: "2.71")

    assert tool.valid?
    assert_equal 3.14, tool.x
    assert_equal 2.71, tool.y
  end

  test "rejects invalid number strings" do
    error = assert_raises(ArgumentError) do
      AddTool.new(x: "not_a_number", y: 5)
    end

    assert_match(/must be a valid number/, error.message)
  end

  test "rejects missing required parameters" do
    tool = AddTool.new(x: 5)

    assert_equal false, tool.valid?
    assert_includes tool.errors.full_messages.join, "can't be blank"
  end

  test "accepts valid array of numbers" do
    tool = NumericArrayTool.new(numbers: [ 1.5, 2.5, 3.5 ])

    assert tool.valid?
    assert_equal [ 1.5, 2.5, 3.5 ], tool.numbers
  end

  test "handles integer parameters" do
    tool = AddTool.new(x: 5, y: 3)

    assert tool.valid?
    assert_equal 5, tool.x
    assert_equal 3, tool.y
  end

  test "validates required collection parameters" do
    tool = NumericArrayTool.new(numbers: [ 1, 2, 3 ])

    # With valid data, tool should be valid
    assert tool.valid?
  end

  test "handles empty array for required collection" do
    tool = NumericArrayTool.new(numbers: [])

    # Empty array is valid - it's still an array
    assert tool.valid?
  end

  test "coerces numeric strings in arrays" do
    tool = NumericArrayTool.new(numbers: [ "1.5", "2.5", "3.5" ])

    assert tool.valid?
    # The FloatArrayType should coerce strings to floats
    assert_equal [ 1.5, 2.5, 3.5 ], tool.numbers
  end

  test "rejects nil for required number parameter" do
    error = assert_raises(ArgumentError) do
      AddTool.new(x: nil, y: 5)
    end

    assert_match(/must be a number/, error.message)
  end

  test "handles zero values correctly" do
    tool = AddTool.new(x: 0, y: 0)

    assert tool.valid?
    assert_equal 0, tool.x
    assert_equal 0, tool.y
  end

  test "handles negative numbers" do
    tool = AddTool.new(x: -5.5, y: -3.2)

    assert tool.valid?
    assert_equal(-5.5, tool.x)
    assert_equal(-3.2, tool.y)
  end

  test "handles very large numbers" do
    large_number = 1e308
    tool = AddTool.new(x: large_number, y: 1)

    assert tool.valid?
    assert_equal large_number, tool.x
  end

  test "handles very small numbers" do
    small_number = 1e-308
    tool = AddTool.new(x: small_number, y: 1)

    assert tool.valid?
    assert_equal small_number, tool.x
  end

  test "validates parameter types are preserved after assignment" do
    tool = AddTool.new(x: 5.0, y: 3.0)

    assert tool.valid?
    assert_kind_of Float, tool.x
    assert_kind_of Float, tool.y
  end

  test "handles mixed integer and float in arrays" do
    tool = NumericArrayTool.new(numbers: [ 1, 2.5, 3 ])

    assert tool.valid?
    # Should all be floats after coercion
    assert tool.numbers.all? { |n| n.is_a?(Float) }
  end
end
