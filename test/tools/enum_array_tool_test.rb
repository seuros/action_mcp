# frozen_string_literal: true

require "test_helper"

class EnumArrayToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  setup do
    @tool = EnumArrayTool.new
  end

  test "tool is registered and available" do
    assert ActionMCP.tools.key?("enum_array")
    assert_equal EnumArrayTool, ActionMCP.tools["enum_array"]
  end

  test "tool metadata is correct" do
    assert_equal "Enum Array Tool", EnumArrayTool.title
    assert_equal "accepts array_string attribute", EnumArrayTool.description
    assert EnumArrayTool.read_only?
    assert EnumArrayTool.idempotent?
  end

  test "schema generation for enum array" do
    schema = EnumArrayTool.to_h[:inputSchema]

    assert_not_nil schema
    assert_equal "object", schema[:type]

    # Check fruits property
    fruits_prop = schema[:properties]["fruits"] || schema[:properties][:fruits]
    assert_not_nil fruits_prop
    assert_equal "array", fruits_prop["type"] || fruits_prop[:type]

    # Check items schema
    items = fruits_prop["items"] || fruits_prop[:items]
    assert_not_nil items
    assert_equal "string", items["type"] || items[:type]

    # Check required
    required = schema[:required] || schema["required"]
    assert required

    # Check enum values
    enum_values = schema[:properties]["fruits"][:enum]
    assert_equal [ "apple", "banana", "cherry" ], enum_values
  end

  test "accepts array of fruits" do
    @tool.fruits = [ "apple", "banana", "cherry" ]
    assert @tool.valid?
    assert_equal [ "apple", "banana", "cherry" ], @tool.fruits
  end

  test "rejects invalid fruit values" do
    @tool.fruits = [ "apple", "orange", "banana" ]
    assert_not @tool.valid?
    assert_includes @tool.errors[:fruits], 'contains invalid value(s) ["orange"], allowed values are: ["apple", "banana", "cherry"]'
  end

  test "handles nil input" do
    @tool.fruits = nil
    # Since we cast nil to [], this should be valid
    assert @tool.valid?
    assert_equal [], @tool.fruits
  end

  test "handles empty array" do
    @tool.fruits = []
    # Empty array should be valid - presence validation allows empty arrays
    assert @tool.valid?
    assert_equal [], @tool.fruits
  end

  test "requires fruits array" do
    # Don't set fruits at all - it should use the default empty array
    # The tool was initialized in setup, so fruits should be []
    assert @tool.valid?
    assert_equal [], @tool.fruits
  end

  test "perform concatenation correctly" do
    @tool.fruits = [ "apple", "banana", "cherry" ]
    result = @tool.call
    assert_not result.is_error
    assert_equal "apple, banana, cherry", result.contents.first.text
  end

  test "call method works correctly" do
    result = EnumArrayTool.call(fruits: [ "apple", "banana", "cherry" ])
    assert_not result.is_error
    assert_equal "apple, banana, cherry", result.contents.first.text
  end

  test "call with empty arguments uses default" do
    result = EnumArrayTool.call({})
    # Should use default empty array and return empty string
    assert_not result.is_error
    assert_equal "", result.contents.first.text
  end

  test "integration with JSON parsing" do
    # Simulate JSON input
    json_input = { "fruits" => [ "apple", "banana", "cherry" ] }
    @tool.assign_attributes(json_input)

    assert @tool.valid?
    assert_equal [ "apple", "banana", "cherry" ], @tool.fruits

    result = @tool.call
    assert_equal "apple, banana, cherry", result.contents.first.text
  end

  test "works with MCP execution" do
    # Use the test helper to execute the tool
    result = execute_mcp_tool("enum_array", fruits: [ "apple", "banana", "cherry" ])
    assert_not result.is_error
    assert_equal "apple, banana, cherry", result.contents.first.text
  end
end
