# frozen_string_literal: true

require "test_helper"

class ToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "AddTool to_h returns correct hash representation inheriting from ArithmeticTool" do
    expected = {
      name: "add",
      description: "Add two numbers together",
      inputSchema: {
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        type: "object",
        properties: {
          "x" => { type: "number", description: "First operand" },
          "y" => { type: "number", description: "Second operand" }
        },
        required: %w[x y],
        additionalProperties: false
      }
    }
    assert_equal expected, AddTool.to_h
  end

  test "ExecuteCommandTool to_h returns correct hash representation" do
    expected = {
      name: "execute_command",
      description: "Run a shell command",
      inputSchema: {
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        type: "object",
        properties: {
          "command" => { type: "string", description: "The command to run" },
          "args" => { type: "array", description: "Command arguments", items: { type: "string" } }
        },
        additionalProperties: false
        # No "required" key since no properties were marked as required.
      }
    }
    assert_equal expected, ExecuteCommandTool.to_h
  end

  test "GitHubCreateIssueTool to_h returns correct hash representation" do
    expected = {
      name: "create_github_issue",
      description: "Create a GitHub issue",
      inputSchema: {
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        type: "object",
        properties: {
          "title" => { type: "string", description: "Issue title" },
          "body" => { type: "string", description: "Issue body" },
          "labels" => { type: "array", description: "Issue labels", items: { type: "string" } }
        },
        additionalProperties: false
        # No required properties.
      }
    }
    assert_equal expected, GitHubCreateIssueTool.to_h
  end

  test "AnalyzeCsvTool to_h returns correct hash representation" do
    expected = {
      name: "analyze_csv",
      description: "Analyze a CSV file",
      inputSchema: {
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        type: "object",
        properties: {
          "filepath" => { type: "string", description: "Path to CSV file" },
          "operations" => { type: "array", description: "Operations to perform",
                            items: { type: "string" } }
        },
        additionalProperties: false
        # No required properties.
      }
    }
    assert_equal expected, AnalyzeCsvTool.to_h
  end

  test "ArithmeticTool is not registered" do
    assert_not ActionMCP::ToolsRegistry.items.key?("arithmetic"), "Abstract tool should not be registered"
  end

  test "CalculateSumTool to_h returns correct hash representation" do
    expected = {
      name: "calculate_sum",
      description: "Calculate the sum of two numbers",
      inputSchema: {
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        type: "object",
        properties: {
          "a" => { type: "number", description: "The first number" },
          "b" => { type: "number", description: "The second number" }
        },
        required: %w[a b],
        additionalProperties: false
      }
    }
    assert_equal expected, CalculateSumTool.to_h
  end

  test "CalculateSumWithPrecisionTool to_h returns correct hash representation with extra property" do
    expected = {
      name: "calculate_sum_with_precision",
      description: "Calculate the sum of two numbers with specified precision",
      inputSchema: {
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        type: "object",
        properties: {
          "a" => { type: "number", description: "The first number" },
          "b" => { type: "number", description: "The second number" },
          "precision" => { type: "number", description: "Decimal precision" },
          "unit" => { type: "string", description: "Unit of measurement" }
        },
        required: %w[a b precision], # "precision" is not required and used only for this test
        additionalProperties: false
      }
    }
    assert_equal expected, CalculateSumWithPrecisionTool.to_h
  end

  test "ExecuteCommandTool to_h returns correct hash representation with simple collection" do
    expected = {
      name: "execute_command",
      description: "Run a shell command",
      inputSchema: {
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        type: "object",
        properties: {
          "command" => { type: "string", description: "The command to run" },
          "args" => { type: "array", description: "Command arguments", items: { type: "string" } }
        },
        additionalProperties: false
        # No required properties specified.
      }
    }
    assert_equal expected, ExecuteCommandTool.to_h
  end
end

class ObjectTypeToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "MetadataTool to_h includes object type in inputSchema" do
    schema = MetadataTool.to_h
    assert_equal "object", schema.dig(:inputSchema, :properties, "attributes", :type)
  end

  test "object property preserves Hash without coercion" do
    attrs = { "env" => "production", "region" => "us-east-1" }
    tool = MetadataTool.new(name: "app", attributes: attrs)
    assert_instance_of Hash, tool.attributes
    assert_equal attrs, tool.attributes
  end

  test "object property returns nil when not provided" do
    tool = MetadataTool.new(name: "app")
    assert_nil tool.attributes
  end
end

class ToolExecutionTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "AddTool returns the correct sum for integers" do
    result = execute_tool("add", x: 5, y: 10)
    assert_tool_output([ { type: "text", text: "15.0" } ], result)
  end

  test "AddTool returns the correct sum for floats" do
    result = execute_tool("add", x: 5.5, y: 10.5)
    assert_tool_output([ { type: "text", text: "16.0" } ], result)
  end

  test "AddTool rejects numeric strings on the MCP boundary" do
    result = execute_tool_with_error("add", x: "5", y: "10")

    assert result.error?
    assert_equal true, result.to_h[:isError]
  end

  test "AddTool returns an error for invalid input" do
    result = execute_tool_with_error("add", x: 5, y: "ten")
    assert result.error?
    assert_equal true, result.to_h[:isError]
    assert_match(/not a number/, result.contents.first.text)
  end

  test "AddTool returns an error for missing input" do
    result = execute_tool_with_error("add", x: 5)
    assert result.error?
    assert_equal true, result.to_h[:isError]
    assert_match(/missing required properties: y/, result.contents.first.text)
  end
end
