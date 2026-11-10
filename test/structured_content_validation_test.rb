# frozen_string_literal: true

require "test_helper"

class StructuredContentValidationTest < ActiveSupport::TestCase
  test "weather tool with forecast passes validation when data matches schema" do
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

  test "validation returns error response when data does not match schema" do
    result = StockReportTool.new(detail: "partial").call

    assert result.error?, "Should be a tool error response"
    assert_equal true, result.to_h[:isError]
    assert_nil result.structured_content, "Should not have structured content on error"
  end

  test "validation passes when all required fields present" do
    result = StockReportTool.new(detail: "full").call

    assert_not result.is_error
    assert_equal "widgets", result.structured_content[:name]
    assert_equal 42, result.structured_content[:count]
  end

  test "tool with an output schema must return structured content" do
    result = StockReportTool.call(detail: "text")

    assert result.error?
    assert_equal true, result.to_h[:isError]
    assert_includes result.to_h.dig(:content, -1, :text), "returned no structured content"
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

    assert_equal ActionMCP::SchemaValidator::DEFAULT_DIALECT, schema["$schema"]
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
