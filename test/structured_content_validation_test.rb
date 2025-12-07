# frozen_string_literal: true

require "test_helper"

class StructuredContentValidationTest < ActiveSupport::TestCase
  setup do
    @original_setting = ActionMCP.configuration.validate_structured_content
  end

  teardown do
    ActionMCP.configuration.validate_structured_content = @original_setting
  end

  test "validation is disabled by default" do
    assert_equal false, ActionMCP.configuration.validate_structured_content
  end

  test "validation can be enabled via configuration" do
    ActionMCP.configuration.validate_structured_content = true
    assert_equal true, ActionMCP.configuration.validate_structured_content
  end

  test "weather tool with forecast passes validation when data matches schema" do
    ActionMCP.configuration.validate_structured_content = true

    tool = WeatherTool.new(location: "NYC", units: "celsius", include_forecast: true)
    result = tool.call

    assert_not result.is_error, "Tool should not return error"
    assert result.structured_content.present?, "Should have structured content"
    assert result.structured_content[:forecast].present?, "Should have forecast"

    # Verify data structure matches schema (has day wrapper)
    first_forecast = result.structured_content[:forecast].first
    assert first_forecast.key?(:day), "Forecast item should have :day wrapper"
    assert first_forecast[:day].key?(:date), "Day should have :date"
  end

  test "validation is skipped when disabled" do
    ActionMCP.configuration.validate_structured_content = false

    # Create a tool with mismatched data/schema - should NOT raise
    tool = WeatherTool.new(location: "NYC", units: "celsius")
    result = tool.call

    assert_not result.is_error
  end

  test "validation returns error response when data does not match schema" do
    ActionMCP.configuration.validate_structured_content = true

    # Create a tool class with intentionally mismatched data
    tool_class = Class.new(ApplicationMCPTool) do
      tool_name "mismatched_tool"
      description "Tool with mismatched data"

      output_schema do
        property :name, type: "string", required: true
        property :count, type: "number", required: true
      end

      def perform
        # Missing required "count" field
        render structured: { name: "test" }
      end
    end

    tool = tool_class.new
    result = tool.call

    # Tool catches exceptions and returns error response
    assert result.is_error, "Should be an error response"
    assert_nil result.structured_content, "Should not have structured content on error"
  end

  test "validation passes when all required fields present" do
    ActionMCP.configuration.validate_structured_content = true

    tool_class = Class.new(ApplicationMCPTool) do
      tool_name "valid_tool"
      description "Tool with valid data"

      output_schema do
        property :name, type: "string", required: true
        property :count, type: "number", required: true
      end

      def perform
        render structured: { name: "test", count: 42 }
      end
    end

    tool = tool_class.new
    result = tool.call

    assert_not result.is_error
    assert_equal "test", result.structured_content[:name]
    assert_equal 42, result.structured_content[:count]
  end

  test "object in array generates correct schema structure" do
    builder = ActionMCP::OutputSchemaBuilder.new
    builder.instance_eval do
      array :items do
        object :entry do
          property :name, type: "string"
          property :value, type: "number"
        end
      end
    end

    schema = builder.to_json_schema
    items_schema = schema.dig("properties", "items", "items")

    # Named object creates wrapper
    assert_equal "object", items_schema["type"]
    assert items_schema["properties"].key?("entry"), "Should have 'entry' property"
    assert_equal "object", items_schema["properties"]["entry"]["type"]
    assert items_schema["properties"]["entry"]["properties"].key?("name")
  end

  test "anonymous object in array generates flat item structure" do
    builder = ActionMCP::OutputSchemaBuilder.new
    builder.instance_eval do
      array :items do
        object do
          property :name, type: "string"
          property :value, type: "number"
        end
      end
    end

    schema = builder.to_json_schema
    items_schema = schema.dig("properties", "items", "items")

    # Anonymous object = items ARE the objects directly
    assert_equal "object", items_schema["type"]
    assert items_schema["properties"].key?("name"), "Should have 'name' property directly"
    assert items_schema["properties"].key?("value"), "Should have 'value' property directly"
    assert_not items_schema["properties"].key?("object"), "Should NOT have 'object' wrapper"
  end
end
