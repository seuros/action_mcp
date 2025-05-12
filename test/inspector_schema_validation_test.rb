require "test_helper"

class InspectorSchemaValidationTest < ActiveSupport::TestCase
  setup do
    # Ensure format_source tool is available
    @format_tool = ValidatedFormatCodeTool
  end

  test "all tools have valid schemas according to MCP Inspector requirements" do
    # Use direct tool reference
    tool_class = @format_tool
    tool_definition = tool_class.to_h

    # Basic structure checks
    assert_not_nil tool_definition[:name], "Tool must have a name"
    assert_not_nil tool_definition[:description], "Tool must have a description"
    assert_not_nil tool_definition[:inputSchema], "Tool must have an inputSchema"

    # Schema structure checks
    schema = tool_definition[:inputSchema]
    assert_equal "object", schema[:type], "Schema type must be 'object' for tool #{tool_definition[:name]}"
    assert schema.key?(:properties), "Schema must have a 'properties' field for tool #{tool_definition[:name]}"
    assert schema[:properties].is_a?(Hash), "Properties must be a hash/object for tool #{tool_definition[:name]}"

    # Check properties structure
    schema[:properties].each do |prop_name, prop_def|
      assert prop_def.is_a?(Hash), "Property #{prop_name} must be a hash for tool #{tool_definition[:name]}"
      assert prop_def.key?(:type), "Property #{prop_name} must have a type for tool #{tool_definition[:name]}"

      # Validate type is one of the allowed JSON Schema types
      valid_types = [ "string", "number", "integer", "boolean", "array", "object", "null" ]
      assert valid_types.include?(prop_def[:type]),
             "Property #{prop_name} has invalid type '#{prop_def[:type]}' for tool #{tool_definition[:name]}"
    end

    # Check required field structure
    if schema.key?(:required)
      assert schema[:required].is_a?(Array),
             "Required field must be an array for tool #{tool_definition[:name]}"

      # Required properties must exist in properties
      schema[:required].each do |req_prop|
        assert schema[:properties].key?(req_prop),
               "Required property '#{req_prop}' must be defined in properties for tool #{tool_definition[:name]}"
      end
    end
  end

  test "format_source tool has correct schema format" do
    # Use direct class reference
    format_tool_class = ValidatedFormatCodeTool

    # Get the tool definition
    tool_def = format_tool_class.to_h

    # Verify name and description
    assert_equal "format_source", tool_def[:name]
    assert_not_nil tool_def[:description]

    # Verify input schema structure
    schema = tool_def[:inputSchema]
    assert_equal "object", schema[:type]
    assert schema.key?(:properties)

    # Verify properties are properly nested
    properties = schema[:properties]
    assert properties.is_a?(Hash)

    # Check required properties
    assert properties.key?("source_code"), "Missing source_code property"
    assert properties.key?("language"), "Missing language property"
    assert properties.key?("style"), "Missing style property"

    # Check property types
    assert_equal "string", properties["source_code"][:type]
    assert_equal "string", properties["language"][:type]
    assert_equal "string", properties["style"][:type]

    # Check required field
    assert schema[:required].is_a?(Array)
    assert schema[:required].include?("source_code")
    assert schema[:required].include?("language")

    # Test that a tool instance can be created and validated
    tool = format_tool_class.new(
      source_code: "function hello() { return 'world'; }",
      language: "javascript"
    )
    assert tool.valid?, "Tool should be valid with required fields"

    # Test validation fails without required fields
    invalid_tool = format_tool_class.new(source_code: "code")
    refute invalid_tool.valid?, "Tool should be invalid without language field"
  end

  test "tool schemas can be serialized to JSON without errors" do
    # Use direct class reference
    tool_class = ValidatedFormatCodeTool
    tool_def = tool_class.to_h

    # Check that the definition can be serialized to JSON
    json_string = nil
    assert_nothing_raised do
      json_string = JSON.generate(tool_def)
    end

    # Verify the JSON can be parsed back
    parsed = nil
    assert_nothing_raised do
      parsed = JSON.parse(json_string)
    end

    # Verify structure is preserved
    assert_equal tool_def[:name], parsed["name"]
    assert_equal "object", parsed["inputSchema"]["type"]
    assert parsed["inputSchema"]["properties"].is_a?(Hash)
  end

  test "all tools meet MCP Inspector validation requirements" do
    # Use direct class reference with protocol version
    tool_def = ValidatedFormatCodeTool.to_h(protocol_version: "2025-03-26")

    # 1. Name must be present and a string
    assert tool_def[:name].is_a?(String), "Name must be a string"
    assert_not_empty tool_def[:name], "Name must not be empty"

    # 2. Description must be present and a string
    assert tool_def[:description].is_a?(String), "Description must be a string"
    assert_not_empty tool_def[:description], "Description must not be empty"

    # 3. InputSchema must be present and valid
    schema = tool_def[:inputSchema]
    assert schema.is_a?(Hash), "InputSchema must be an object"

    # 4. InputSchema must follow the JSON Schema structure
    assert_equal "object", schema[:type], "Schema type must be object"
    assert schema[:properties].is_a?(Hash), "Properties must be an object"

    # 5. Properties must all have valid types
    schema[:properties].each do |name, prop|
      assert prop.is_a?(Hash), "Property definition must be an object"
      assert prop[:type].is_a?(String), "Property type must be a string"
    end

    # 6. If required is present, it must be an array of strings
    if schema[:required]
      assert schema[:required].is_a?(Array), "Required must be an array"
      assert schema[:required].all? { |r| r.is_a?(String) }, "Required items must be strings"
      assert schema[:required].all? { |r| schema[:properties].key?(r) },
             "Required properties must exist in properties"
    end
  end
end
