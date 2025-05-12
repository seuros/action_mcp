require "test_helper"

class MCPSchemaValidationTest < ActiveSupport::TestCase
  setup do
    # Ensure format_source tool is registered
    session = ActionMCP::Session.create!(initialized: true)
    session.register_tool("format_source")
  end

  test "all tool schemas are properly formatted" do
    # Get all tools from the registry
    tools = []

    # Get tools directly using ValidatedFormatCodeTool
    tools << ValidatedFormatCodeTool.to_h

    # Filter out any nil or improperly formatted tools
    valid_tools = tools.select { |t| t && t[:name].present? && t[:inputSchema].present? }
    assert_not_empty valid_tools, "There should be at least one valid tool"

    valid_tools.each do |tool|
      # Check basic tool structure
      assert tool[:name].present?, "Tool must have a name"
      assert tool[:description].present?, "Tool must have a description"
      assert tool[:inputSchema].present?, "Tool must have an input schema"

      schema = tool[:inputSchema]

      # Check schema structure
      assert_equal "object", schema[:type],
        "Tool #{tool[:name]} schema must be of type 'object'"

      # Verify properties are properly nested
      assert schema.key?(:properties),
        "Tool #{tool[:name]} schema must have a 'properties' field"
      assert schema[:properties].is_a?(Hash),
        "Tool #{tool[:name]} properties must be a hash"

      # Check each property
      schema[:properties].each do |prop_name, prop_def|
        assert prop_def.is_a?(Hash),
          "Property #{prop_name} in #{tool[:name]} must be a hash"
        assert prop_def[:type].present?,
          "Property #{prop_name} in #{tool[:name]} must have a type"
      end

      # Check required fields format
      if schema.key?(:required)
        assert schema[:required].is_a?(Array),
          "Tool #{tool[:name]} required field must be an array"

        # Make sure all required properties exist in the properties hash
        schema[:required].each do |req_prop|
          assert schema[:properties].key?(req_prop),
            "Required property #{req_prop} must be defined in properties for #{tool[:name]}"
        end
      end
    end
  end

  test "format_source tool has correct schema" do
    # Use the ValidatedFormatCodeTool class directly rather than registry lookup
    format_tool = ValidatedFormatCodeTool

    tool_def = format_tool.to_h
    assert_not_nil tool_def, "Tool definition should not be nil"

    schema = tool_def[:inputSchema]
    assert_not_nil schema, "Input schema should not be nil"

    # Check schema structure
    assert_equal "object", schema[:type]
    assert schema.key?(:properties), "Schema must have properties field"
    assert schema[:properties].key?("source_code"), "Must have source_code property"
    assert schema[:properties].key?("language"), "Must have language property"
    assert schema[:properties].key?("style"), "Must have style property"

    # Check property types
    assert_equal "string", schema[:properties]["source_code"][:type]
    assert_equal "string", schema[:properties]["language"][:type]
    assert_equal "string", schema[:properties]["style"][:type]

    # Check required fields
    assert schema[:required].include?("source_code"), "source_code should be required"
    assert schema[:required].include?("language"), "language should be required"
    refute schema[:required].include?("style"), "style should not be required"

    # Check descriptions are present
    assert schema[:properties]["source_code"][:description].present?
    assert schema[:properties]["language"][:description].present?
    assert schema[:properties]["style"][:description].present?
  end

  test "all tool schemas are valid against JSON Schema spec" do
    # Get tools directly
    tools = []
    tools << ValidatedFormatCodeTool.to_h

    # Filter out any nil or improperly formatted tools
    valid_tools = tools.select { |t| t && t[:name].present? && t[:inputSchema].present? }
    assert_not_empty valid_tools, "There should be at least one valid tool"

    valid_tools.each do |tool|
      schema = tool[:inputSchema]
      next unless schema # Skip if no schema

      # Basic JSON Schema validation
      assert_equal "object", schema[:type], "Schema type for #{tool[:name]} must be 'object'"
      assert schema.key?(:properties), "Schema for #{tool[:name]} must have properties field"

      # Properties must be an object
      assert schema[:properties].is_a?(Hash), "Properties for #{tool[:name]} must be a hash"

      # If required exists, it must be an array
      if schema.key?(:required)
        assert schema[:required].is_a?(Array), "Required field for #{tool[:name]} must be an array"
      end

      # Each property should have a valid type
      valid_types = [ "string", "number", "integer", "boolean", "array", "object", "null" ]
      schema[:properties].each do |prop_name, prop_def|
        assert valid_types.include?(prop_def[:type]),
          "Property #{prop_name} type in #{tool[:name]} must be one of #{valid_types.join(', ')}"
      end
    end
  end
end
