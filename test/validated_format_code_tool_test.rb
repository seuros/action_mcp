# frozen_string_literal: true

require "test_helper"

class ValidatedFormatCodeToolTest < ActiveSupport::TestCase
  test "tool has valid schema structure" do
    # Get the tool definition
    tool_def = ValidatedFormatCodeTool.to_h

    # Verify basic attributes
    assert_equal "format_source", tool_def[:name]
    assert_equal "Format source code according to a specific coding style", tool_def[:description]
    assert_not_nil tool_def[:inputSchema]

    # Check schema structure
    schema = tool_def[:inputSchema]
    assert_equal "object", schema[:type]
    assert schema.key?(:properties)
    assert schema[:properties].is_a?(Hash)

    # Check required properties
    assert schema.key?(:required)
    assert_includes schema[:required], "source_code"
    assert_includes schema[:required], "language"
    refute_includes schema[:required], "style"

    # Verify each property has the correct format
    properties = schema[:properties]
    assert properties.key?("source_code")
    assert properties["source_code"].is_a?(Hash)
    assert_equal "string", properties["source_code"][:type]
    assert properties["source_code"][:description].present?

    assert properties.key?("language")
    assert_equal "string", properties["language"][:type]
    assert properties["language"][:description].present?

    assert properties.key?("style")
    assert_equal "string", properties["style"][:type]
    assert properties["style"][:description].present?
  end

  test "tool serializes to valid JSON" do
    tool_def = ValidatedFormatCodeTool.to_h

    # Verify it can be serialized to JSON without errors
    json_string = nil
    assert_nothing_raised do
      json_string = JSON.generate(tool_def)
    end

    # Verify the JSON can be parsed back
    parsed = nil
    assert_nothing_raised do
      parsed = JSON.parse(json_string)
    end

    # Check the structure is preserved
    assert_equal "format_source", parsed["name"]
    assert_equal "object", parsed["inputSchema"]["type"]
    assert parsed["inputSchema"]["properties"].is_a?(Hash)
    assert parsed["inputSchema"]["properties"].key?("source_code")
  end

  test "tool can be instantiated and validated" do
    # Create valid instance
    tool = ValidatedFormatCodeTool.new(
      source_code: "function hello() { return 'world'; }",
      language: "javascript"
    )

    # Should pass validation
    assert tool.valid?, "Tool instance should be valid with required params"

    # Create invalid instance (missing required param)
    invalid_tool = ValidatedFormatCodeTool.new(
      source_code: "def hello; 'world'; end"
    )

    # Should fail validation
    refute invalid_tool.valid?, "Tool should be invalid without language"
    assert invalid_tool.errors.key?(:language), "Should have error on language"
  end

  test "tool performs formatting correctly" do
    # JavaScript formatting
    js_tool = ValidatedFormatCodeTool.new(
      source_code: "function   hello()   {   return   'world';   }",
      language: "javascript"
    )
    js_response = js_tool.call
    assert js_response.success?
    js_content = js_response.contents.first
    assert_equal "function hello() { return 'world'; }", js_content.text.strip

    # Ruby formatting
    ruby_tool = ValidatedFormatCodeTool.new(
      source_code: "def   hello   \nreturn   'world'\nend",
      language: "ruby"
    )
    ruby_response = ruby_tool.call
    assert ruby_response.success?
    ruby_content = ruby_response.contents.first
    assert ruby_content.text.include?("def hello"), "Should format Ruby code correctly"

    # Test with style option
    style_tool = ValidatedFormatCodeTool.new(
      source_code: "function test() { return true; }",
      language: "javascript",
      style: "compact"
    )
    style_response = style_tool.call
    assert style_response.success?
  end
end
