# frozen_string_literal: true

require "test_helper"

class ToolAdditionalPropertiesTest < ActiveSupport::TestCase
  test "tool with additional_properties true includes additionalProperties in schema" do
    tool_class = FlexibleApiTool
    tool_hash = tool_class.to_h

    assert_includes tool_hash[:inputSchema], :additionalProperties
    assert_equal({}, tool_hash[:inputSchema][:additionalProperties])
  end

  test "tool with typed additional_properties includes typed schema" do
    tool_class = TypedAdditionalPropsTool
    tool_hash = tool_class.to_h

    assert_includes tool_hash[:inputSchema], :additionalProperties
    assert_equal({ "type" => "string" }, tool_hash[:inputSchema][:additionalProperties])
  end

  test "tool without additional_properties does not include additionalProperties" do
    # Use existing AddTool which doesn't have additional_properties
    tool_class = AddTool
    tool_hash = tool_class.to_h

    refute_includes tool_hash[:inputSchema], :additionalProperties
  end

  test "tool with additional_properties false explicitly disallows extra properties" do
    # Create a test class with additional_properties false
    test_class = Class.new(ActionMCP::Tool) do
      tool_name "no_additional_props_test"
      description "Test tool with additional_properties false"
      property :name, type: "string", required: true
      additional_properties false
    end

    tool_hash = test_class.to_h
    assert_includes tool_hash[:inputSchema], :additionalProperties
    assert_equal false, tool_hash[:inputSchema][:additionalProperties]
  end

  test "tool accepts additional parameters when additional_properties is enabled" do
    # Test with FlexibleApiTool
    params = {
      "endpoint" => "/api/test",
      "method" => "POST",
      "extra_param1" => "value1",
      "extra_param2" => 123,
      "extra_param3" => true
    }

    tool = FlexibleApiTool.new(params)

    # Defined properties should be accessible normally
    assert_equal "/api/test", tool.endpoint
    assert_equal "POST", tool.method

    # Additional properties should be in additional_params
    expected_additional = {
      "extra_param1" => "value1",
      "extra_param2" => 123,
      "extra_param3" => true
    }
    assert_equal expected_additional, tool.additional_params
  end

  test "tool without additional_properties rejects extra parameters" do
    # Use existing AddTool which doesn't have additional_properties
    params = {
      "x" => 5,
      "y" => 3,
      "extra_param" => "ignored"
    }

    # Should raise an error when extra parameters are provided to a tool that doesn't accept them
    assert_raises(ActiveModel::UnknownAttributeError) do
      AddTool.new(params)
    end

    # Test with valid parameters only
    valid_params = { "x" => 5, "y" => 3 }
    tool = AddTool.new(valid_params)

    assert_equal 5, tool.x
    assert_equal 3, tool.y
    assert_equal({}, tool.additional_params)
  end

  test "tool validation works correctly with additional parameters" do
    # Test valid case
    valid_params = {
      "endpoint" => "/api/test",
      "extra_param" => "value"
    }
    tool = FlexibleApiTool.new(valid_params)
    assert tool.valid?

    # Test invalid case - missing required parameter
    invalid_params = {
      "extra_param" => "value"
      # missing required 'endpoint'
    }
    tool = FlexibleApiTool.new(invalid_params)
    refute tool.valid?
    assert_includes tool.errors.full_messages.join, "Endpoint"
  end

  test "tool call method works with additional parameters" do
    params = {
      "endpoint" => "/api/test",
      "method" => "POST",
      "debug" => true,
      "timeout" => 5000
    }

    response = FlexibleApiTool.call(params)

    refute response.error?
    assert response.contents.any? { |c| c.text&.include?("debug: true") }
    assert response.contents.any? { |c| c.text&.include?("timeout: 5000") }
  end

  test "tool class methods for checking additional_properties" do
    assert FlexibleApiTool.accepts_additional_properties?
    assert TypedAdditionalPropsTool.accepts_additional_properties?
    refute AddTool.accepts_additional_properties?

    # Test specific values
    assert_equal true, FlexibleApiTool.additional_properties
    assert_equal({ "type" => "string" }, TypedAdditionalPropsTool.additional_properties)
    assert_nil AddTool.additional_properties
  end

  test "output schema builder supports additional_properties" do
    tool_class = Class.new(ActionMCP::Tool) do
      tool_name "output_schema_test"
      description "Test tool with output schema additional properties"

      output_schema do
        string :message, required: true
        object :metadata, additional_properties: true do
          string :source
        end
        additional_properties false
      end
    end

    schema = tool_class._output_schema

    # Root level should have additionalProperties: false
    assert_equal false, schema["additionalProperties"]

    # Nested object should have additionalProperties: {}
    metadata_schema = schema["properties"]["metadata"]
    assert_equal({}, metadata_schema["additionalProperties"])
  end
end
