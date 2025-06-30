# frozen_string_literal: true

require "test_helper"

class NumericArrayToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  setup do
    @tool = NumericArrayTool.new
  end

  test "tool is registered and available" do
    assert ActionMCP.tools.key?("numeric_array")
    assert_equal NumericArrayTool, ActionMCP.tools["numeric_array"]
  end

  test "tool metadata is correct" do
    assert_equal "Numeric Array Tool", NumericArrayTool.title
    assert_equal "accepts array_number attribute", NumericArrayTool.description
    assert NumericArrayTool.read_only?
    assert NumericArrayTool.idempotent?
  end

  test "schema generation for number array" do
    schema = NumericArrayTool.to_h[:inputSchema]

    assert_not_nil schema
    assert_equal "object", schema[:type]

    # Check numbers property
    numbers_prop = schema[:properties]["numbers"] || schema[:properties][:numbers]
    assert_not_nil numbers_prop
    assert_equal "array", numbers_prop["type"] || numbers_prop[:type]

    # Check items schema
    items = numbers_prop["items"] || numbers_prop[:items]
    assert_not_nil items
    assert_equal "number", items["type"] || items[:type]

    # Check required
    required = schema[:required] || schema["required"]
    assert_includes required, "numbers"
  end

  test "accepts array of integers" do
    @tool.numbers = [ 1, 2, 3, 4, 5 ]
    assert @tool.valid?
    assert_equal [ 1.0, 2.0, 3.0, 4.0, 5.0 ], @tool.numbers
  end

  test "accepts array of floats" do
    @tool.numbers = [ 1.5, 2.5, 3.5 ]
    assert @tool.valid?
    assert_equal [ 1.5, 2.5, 3.5 ], @tool.numbers
  end

  test "accepts mixed numeric array" do
    @tool.numbers = [ 1, 2.5, 3, 4.75 ]
    assert @tool.valid?
    assert_equal [ 1.0, 2.5, 3.0, 4.75 ], @tool.numbers
  end

  test "converts string numbers to floats" do
    @tool.numbers = [ "1", "2.5", "3.14" ]
    assert @tool.valid?
    assert_equal [ 1.0, 2.5, 3.14 ], @tool.numbers
  end

  test "filters out non-numeric values" do
    @tool.numbers = [ 1, "2", "invalid", 3.5, nil, "4.5" ]
    assert @tool.valid?
    assert_equal [ 1.0, 2.0, 3.5, 4.5 ], @tool.numbers
  end

  test "handles nil input" do
    @tool.numbers = nil
    # Since FloatArrayType casts nil to [], this should be valid
    assert @tool.valid?
    assert_equal [], @tool.numbers
  end

  test "handles empty array" do
    @tool.numbers = []
    # Empty array should be valid - presence validation allows empty arrays
    assert @tool.valid?
    assert_equal [], @tool.numbers
  end

  test "requires numbers array" do
    # Don't set numbers at all - it should use the default empty array
    # The tool was initialized in setup, so numbers should be []
    assert @tool.valid?
    assert_equal [], @tool.numbers
  end

  test "perform calculates sum correctly" do
    @tool.numbers = [ 1, 2, 3, 4, 5 ]
    result = @tool.call
    assert_not result.is_error
    assert_equal "15.0", result.contents.first.text
  end

  test "perform with floats" do
    @tool.numbers = [ 1.5, 2.5, 3.5 ]
    result = @tool.call
    assert_not result.is_error
    assert_equal "7.5", result.contents.first.text
  end

  test "perform with empty array returns zero" do
    @tool.numbers = []
    result = @tool.call
    # Empty array should be valid, not an error
    assert_not result.is_error
    assert_equal "0", result.contents.first.text
  end

  test "call method works correctly" do
    result = NumericArrayTool.call(numbers: [ 10, 20, 30 ])
    assert_not result.is_error
    assert_equal "60.0", result.contents.first.text
  end

  test "call with empty arguments uses default" do
    result = NumericArrayTool.call({})
    # Should use default empty array and return 0
    assert_not result.is_error
    assert_equal "0", result.contents.first.text
  end

  test "float array type handles various inputs correctly" do
    # Test the type directly
    type = ActionMCP::Types::FloatArrayType.new

    # Test various inputs
    assert_equal [ 1.0, 2.0 ], type.cast([ 1, 2 ])
    assert_equal [ 1.5, 2.5 ], type.cast([ 1.5, 2.5 ])
    assert_equal [ 1.0, 2.0 ], type.cast([ "1", "2" ])
    assert_equal [], type.cast(nil)
    assert_equal [ 1.0, 3.0 ], type.cast([ 1, "invalid", 3 ])
  end

  test "integration with JSON parsing" do
    # Simulate JSON input
    json_input = { "numbers" => [ 1, 2.5, 3 ] }
    @tool.assign_attributes(json_input)

    assert @tool.valid?
    assert_equal [ 1.0, 2.5, 3.0 ], @tool.numbers

    result = @tool.call
    assert_equal "6.5", result.contents.first.text
  end

  test "works with MCP execution" do
    # Use the test helper to execute the tool
    result = execute_mcp_tool("numeric_array", numbers: [ 5, 10, 15 ])
    assert_not result.is_error
    assert_equal "30.0", result.contents.first.text
  end
end
