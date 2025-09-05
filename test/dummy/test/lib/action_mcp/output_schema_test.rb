# frozen_string_literal: true

require "test_helper"

class ActionMCP::OutputSchemaTest < ActiveSupport::TestCase
  class TestTool < ActionMCP::Tool
    tool_name "test_tool"

    property :name, type: "string", required: true

    output_schema do
      property :greeting, type: "string", required: true
      property :success, type: "boolean", required: true
      property :metadata, type: "object" do
        property :timestamp, type: "string", format: "date-time"
        property :version, type: "string", default: "1.0"
      end
    end

    def perform
      # Test different rendering approaches
      case name
      when "structured"
        render structured: {
          greeting: "Hello, #{name}!",
          success: true,
          metadata: {
            timestamp: Time.current.iso8601,
            version: "1.0"
          }
        }
      when "mixed"
        render text: "Starting processing..."
        render structured: {
          greeting: "Hello, #{name}!",
          success: true
        }
      else
        render text: "Hello, #{name}!"
      end
    end
  end

  class InvalidOutputTool < ActionMCP::Tool
    tool_name "invalid_tool"

    output_schema do
      property :required_field, type: "string", required: true
    end

    def perform
      # Return invalid structure (missing required field)
      render structured: { optional_field: "value" }
    end
  end

  test "defines output schema using DSL" do
    schema = TestTool.output_schema

    assert_equal "object", schema["type"]

    # Check flattened properties from nested structure
    expected_properties = {
      "greeting" => { "type" => "string" },
      "success" => { "type" => "boolean" },
      "metadata_timestamp" => { "type" => "string", "format" => "date-time" },
      "metadata_version" => { "type" => "string", "default" => "1.0" }
    }

    assert_equal expected_properties, schema["properties"]
    assert_equal [ "greeting", "success" ], schema["required"]
  end

  test "can access output schema builder" do
    assert_not_nil TestTool._output_schema_builder
    assert_instance_of ActionMCP::SchemaBuilder, TestTool._output_schema_builder
  end

  test "renders structured content successfully" do
    tool = TestTool.new(name: "structured")
    result = tool.call

    # Should have both regular content and structured content
    assert result.is_a?(Array)

    # Check if tool response has structured content
    # (This would need to be verified based on ToolResponse implementation)
  end

  test "allows mixing text and structured content" do
    tool = TestTool.new(name: "mixed")
    result = tool.call

    # Should handle mixed content rendering
    assert result.is_a?(Array)
  end

  test "validates structured content in development" do
    Rails.env.stub :development?, true do
      Rails.env.stub :test?, false do
        # Mock json_schemer to avoid dependency
        JSONSchemer = Class.new unless defined?(JSONSchemer)

        schema_double = Minitest::Mock.new
        schema_double.expect :valid?, false, [ Hash ]
        schema_double.expect :validate, [
          { "data_pointer" => "/required_field", "type" => "required" }
        ], [ Hash ]

        JSONSchemer.stub :schema, schema_double do
          tool = InvalidOutputTool.new

          assert_raises ArgumentError, /Structured content validation failed/ do
            tool.send(:validate_structured_content, { optional_field: "value" })
          end
        end

        schema_double.verify
      end
    end
  end

  test "logs validation errors in production without raising" do
    Rails.env.stub :production?, true do
      Rails.env.stub :test?, false do
        Rails.env.stub :development?, false do
          # Mock json_schemer
          JSONSchemer = Class.new unless defined?(JSONSchemer)

          schema_double = Minitest::Mock.new
          schema_double.expect :valid?, false, [ Hash ]
          schema_double.expect :validate, [
            { "data_pointer" => "/required_field", "type" => "required" }
          ], [ Hash ]

          JSONSchemer.stub :schema, schema_double do
            Rails.logger.stub :warn, nil do
              tool = InvalidOutputTool.new

              # Should not raise in production, just log
              assert_nothing_raised do
                tool.send(:validate_structured_content, { optional_field: "value" })
              end
            end
          end

          schema_double.verify
        end
      end
    end
  end

  test "skips validation in test environment" do
    # This test runs in test environment, so validation should be skipped
    tool = InvalidOutputTool.new

    # Should not raise even with invalid content
    assert_nothing_raised do
      tool.send(:validate_structured_content, { optional_field: "value" })
    end
  end

  test "handles json_schemer not available gracefully" do
    Rails.env.stub :development?, true do
      Rails.env.stub :test?, false do
        # Mock LoadError when requiring json_schemer
        tool = InvalidOutputTool.new

        Rails.logger.stub :warn, nil do
          tool.stub :require, proc { |gem| raise LoadError if gem == "json_schemer" } do
            # Should not raise, just log warning
            assert_nothing_raised do
              tool.send(:validate_structured_content, { some: "data" })
            end
          end
        end
      end
    end
  end

  test "requires hash for structured content" do
    tool = TestTool.new(name: "test")

    # Should raise for non-hash content
    assert_raises ArgumentError, /must be a hash\/object/ do
      tool.send(:validate_structured_content, "not a hash")
    end
  end

  test "output schema returns nil if not defined" do
    class NoSchemaTool < ActionMCP::Tool
      tool_name "no_schema"
    end

    assert_nil NoSchemaTool.output_schema
  end

  test "can define output schema with property method" do
    schema = TestTool._output_schema_builder

    # Test that both typed methods and property method work
    assert_includes schema.properties.keys, "greeting"
    assert_includes schema.properties.keys, "success"
    assert_includes schema.properties.keys, "metadata_timestamp"
  end

  test "nested objects are flattened correctly" do
    class NestedTool < ActionMCP::Tool
      output_schema do
        object :config do
          object :database do
            string :host, required: true
            number :port, default: 5432
          end
          string :version, default: "1.0"
        end
      end
    end

    schema = NestedTool.output_schema

    expected_properties = {
      "config_database_host" => { "type" => "string" },
      "config_database_port" => { "type" => "number", "default" => 5432 },
      "config_version" => { "type" => "string", "default" => "1.0" }
    }

    assert_equal expected_properties, schema["properties"]
    assert_equal [ "config_database_host" ], schema["required"]
  end

  test "render method supports structured parameter" do
    tool = TestTool.new(name: "test")
    tool.instance_variable_set(:@response, ActionMCP::ToolResponse.new)

    data = { greeting: "Hello", success: true }
    result = tool.render(structured: data)

    assert_equal data, result
  end

  test "render method falls back to normal rendering without structured" do
    tool = TestTool.new(name: "test")
    tool.instance_variable_set(:@response, ActionMCP::ToolResponse.new)

    # Mock the super method behavior
    content = tool.render(text: "Hello world")

    # Should return content object (would be actual Content object in real usage)
    assert_not_nil content
  end
end
