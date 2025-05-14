# frozen_string_literal: true

require "test_helper"

class FormatSourceToolTest < ActiveSupport::TestCase
  test "format_source tool has correct schema structure" do
    # Use the ValidatedFormatCodeTool class directly
    format_tool = ValidatedFormatCodeTool
    assert_not_nil format_tool, "format_source tool should be registered"

    # Get the tool definition
    tool_def = format_tool.to_h
    assert_not_nil tool_def, "Tool definition should not be nil"

    # Check basic tool structure
    assert_equal "format_source", tool_def[:name], "Tool should have the correct name"
    assert_not_nil tool_def[:description], "Tool should have a description"
    assert_not_nil tool_def[:inputSchema], "Tool should have an input schema"

    schema = tool_def[:inputSchema]

    # Check schema structure
    assert_equal "object", schema[:type], "Schema should be of type 'object'"
    assert schema.key?(:properties), "Schema must have properties field"
    assert schema[:properties].is_a?(Hash), "Properties must be a hash"

    # Check specific properties exist
    assert schema[:properties].key?("source_code"), "Must have source_code property"
    assert schema[:properties].key?("language"), "Must have language property"
    assert schema[:properties].key?("style"), "Must have style property"

    # Check property types
    assert_equal "string", schema[:properties]["source_code"][:type], "source_code should be a string"
    assert_equal "string", schema[:properties]["language"][:type], "language should be a string"
    assert_equal "string", schema[:properties]["style"][:type], "style should be a string"

    # Check required fields
    assert schema[:required].is_a?(Array), "required should be an array"
    assert schema[:required].include?("source_code"), "source_code should be required"
    assert schema[:required].include?("language"), "language should be required"
    refute schema[:required].include?("style"), "style should not be required"

    # Check descriptions are present
    assert schema[:properties]["source_code"][:description].present?, "source_code should have a description"
    assert schema[:properties]["language"][:description].present?, "language should have a description"
    assert schema[:properties]["style"][:description].present?, "style should have a description"
  end

  test "format_source tool can be invoked with valid parameters" do
    # Create tool instance
    tool = ValidatedFormatCodeTool.new(
      source_code: "function   hello()   {   return   'world';   }",
      language: "javascript"
    )

    # Execute the tool
    response = tool.call

    # Check the response
    assert_not response.is_error, "Tool execution should not produce an error"
    assert_equal 1, response.contents.size, "Should return one content item"

    content = response.contents.first
    assert_equal "text", content.type, "Content should be of type text"
    assert_includes content.text.strip, "function hello() { return 'world'; }", "Should return formatted code"
  end
end
