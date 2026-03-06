# frozen_string_literal: true

require "test_helper"

class EnumToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  setup do
    @tool = EnumTool.new
  end

  test "tool is registered and available" do
    assert ActionMCP.tools.key?("enum")
    assert_equal EnumTool, ActionMCP.tools["enum"]
  end

  test "tool metadata is correct" do
    assert_equal "Enum Tool", EnumTool.title
    assert_equal "accepts enum attribute", EnumTool.description
    assert EnumTool.read_only?
    assert EnumTool.idempotent?
  end

  test "schema generation for enum array" do
    schema = EnumTool.to_h[:inputSchema]

    assert_not_nil schema
    assert_equal "object", schema[:type]

    # Check fruit property
    fruit_prop = schema[:properties]["fruit"] || schema[:properties][:fruit]
    assert_not_nil fruit_prop
    assert_equal "string", fruit_prop["type"] || fruit_prop[:type]
    assert_equal [ "apple", "banana", "cherry" ], fruit_prop["enum"] || fruit_prop[:enum]

    # Check required
    required = schema[:required] || schema["required"]
    assert_includes required, "fruit"
  end

  test "rejects invalid fruit values" do
    @tool.fruit = "orange"
    assert_not @tool.valid?
    assert_includes @tool.errors[:fruit], "is not included in the list"
  end

  test "handles nil input" do
    @tool.fruit = nil
    # Since FloatArrayType casts nil to [], this should be valid
    assert_not @tool.valid?
    assert_nil @tool.fruit
  end

  test "call method works correctly" do
    result = EnumTool.call(fruit: "apple")
    assert_not result.is_error
    assert_equal "apple", result.contents.first.text
  end

  test "integration with JSON parsing" do
    # Simulate JSON input
    json_input = { "fruit" => "apple" }
    @tool.assign_attributes(json_input)

    assert @tool.valid?
    assert_equal "apple", @tool.fruit

    result = @tool.call
    assert_equal "apple", result.contents.first.text
  end

  test "works with MCP execution" do
    # Use the test helper to execute the tool
    result = execute_mcp_tool("enum", fruit: "apple")
    assert_not result.is_error
    assert_equal "apple", result.contents.first.text
  end
end
