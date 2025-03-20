# frozen_string_literal: true

require "test_helper"

class ToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  test "AddTool to_h returns correct hash representation inheriting from ArithmeticTool" do
    expected = {
      name: "add",
      description: "Add two numbers together",
      inputSchema: {
        type: "object",
        properties: {
          "x" => { type: "number", description: "First operand" },
          "y" => { type: "number", description: "Second operand" }
        },
        required: %w[x y]
      }
    }
    assert_equal expected, AddTool.to_h
  end

  test "ExecuteCommandTool to_h returns correct hash representation" do
    expected = {
      name: "execute_command",
      description: "Run a shell command",
      inputSchema: {
        type: "object",
        properties: {
          "command" => { type: "string", description: "The command to run" },
          "args" => { type: "array", description: "Command arguments", items: { type: "string" } }
        }
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
        type: "object",
        properties: {
          "title" => { type: "string", description: "Issue title" },
          "body" => { type: "string", description: "Issue body" },
          "labels" => { type: "array", description: "Issue labels", items: { type: "string" } }
        }
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
        type: "object",
        properties: {
          "filepath" => { type: "string", description: "Path to CSV file" },
          "operations" => { type: "array", description: "Operations to perform",
                            items: { type: "string" } }
        }
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
        type: "object",
        properties: {
          "number1" => { type: "number", description: "The first number" },
          "number2" => { type: "number", description: "The second number" }
        },
        required: %w[number1 number2]
      }
    }
    assert_equal expected, CalculateSumTool.to_h
  end

  test "CalculateSumWithPrecisionTool to_h returns correct hash representation with extra property" do
    expected = {
      name: "calculate_sum_with_precision",
      description: "Calculate the sum of two numbers with specified precision",
      inputSchema: {
        type: "object",
        properties: {
          "number1" => { type: "number", description: "The first number" },
          "number2" => { type: "number", description: "The second number" },
          "precision" => { type: "number", description: "Decimal precision" },
          "unit" => { type: "string", description: "Unit of measurement" }
        },
        required: %w[number1 number2 precision] # "precision" is not required and used only for this test
      }
    }
    assert_equal expected, CalculateSumWithPrecisionTool.to_h
  end

  test "ExecuteCommandTool to_h returns correct hash representation with simple collection" do
    expected = {
      name: "execute_command",
      description: "Run a shell command",
      inputSchema: {
        type: "object",
        properties: {
          "command" => { type: "string", description: "The command to run" },
          "args" => { type: "array", description: "Command arguments", items: { type: "string" } }
        }
        # No required properties specified.
      }
    }
    assert_equal expected, ExecuteCommandTool.to_h
  end
end
