# frozen_string_literal: true

require "test_helper"

class ActionMCP::ToolParameterValidationTest < ActiveSupport::TestCase
  test "rejects non-numeric parameter for number property" do
    tool = AddTool.from_wire(x: "not_a_number", y: 5)

    refute tool.valid?
    assert_match(/not a number/, tool.errors.full_messages.join)
    assert_equal true, tool.call.to_h[:isError]
  end

  test "rejects non-array parameter for collection property" do
    tool = NumericArrayTool.from_wire(numbers: "not_an_array")

    refute tool.valid?
    assert_match(/not an array/, tool.errors.full_messages.join)
  end

  test "accepts valid numeric parameters" do
    tool = AddTool.new(x: 3.14, y: 2.71)

    assert tool.valid?
    assert_equal 3.14, tool.x
    assert_equal 2.71, tool.y
  end

  test "rejects numeric strings before ActiveModel coercion" do
    tool = AddTool.from_wire(x: "3.14", y: "2.71")

    refute tool.valid?
    assert_equal true, tool.call.to_h[:isError]
  end

  test "rejects invalid number strings" do
    tool = AddTool.from_wire(x: "not_a_number", y: 5)

    refute tool.valid?
    assert_match(/not a number/, tool.errors.full_messages.join)
  end

  test "rejects missing required parameters" do
    tool = AddTool.from_wire(x: 5)

    assert_equal false, tool.valid?
    assert_includes tool.errors.full_messages.join, "missing required properties: y"
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

  test "rejects numeric strings in arrays" do
    tool = NumericArrayTool.from_wire(numbers: [ "1.5", "2.5", "3.5" ])

    refute tool.valid?
    assert_match(/not a number/, tool.errors.full_messages.join)
  end

  test "rejects nil for required number parameter" do
    tool = AddTool.from_wire(x: nil, y: 5)

    refute tool.valid?
    assert_match(/not a number/, tool.errors.full_messages.join)
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

  test "enforces the complete advertised JSON Schema" do
    tool_class = Class.new(ActionMCP::Tool) do
      tool_name "schema_constraint_test"
      property :mode, type: "string", enum: [ "fast", "safe" ], required: true
      property :port, type: "integer", minimum: 1, maximum: 65_535, required: true
      property :endpoint, type: "string", format: "uri", required: true
      property :settings,
               type: "object",
               properties: { enabled: { type: "boolean" } },
               allOf: [ { required: [ "enabled" ] } ],
               additionalProperties: false,
               required: true
    end

    tool = tool_class.new(
      mode: "turbo",
      port: 70_000,
      endpoint: "not a uri",
      settings: { enabled: "yes", extra: true }
    )

    refute tool.valid?
    messages = tool.errors.full_messages.join(" ")
    assert_match(/not one of/, messages)
    assert_match(/greater than: 65535/, messages)
    assert_match(/does not match format: uri/, messages)
    assert_match(/not a boolean/, messages)
    assert_match(/disallowed additional property/, messages)
  end
end
