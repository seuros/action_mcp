# frozen_string_literal: true

require "test_helper"

class AllToolsAndPromptsTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  # Tools
  test "AddTool is findable" do
    assert_tool_findable("add")
  end

  test "AnalyzeCsvTool is findable" do
    assert_tool_findable("analyze_csv")
  end

  test "CalculateSumTool is findable" do
    assert_tool_findable("calculate_sum")
    result = execute_tool("calculate_sum", a: 1, b: 2)
    assert_tool_output([ { type: "text", text: "3.0" } ], result)
  end

  test "CalculateSumWithPrecisionTool is findable" do
    assert_tool_findable("calculate_sum_with_precision")
  end

  test "ChecksumCheckerTool is findable" do
    assert_tool_findable("checksum_checker")
  end

  test "ExecuteCommandTool is findable" do
    assert_tool_findable("execute_command")
  end

  test "FormatCodeTool is findable" do
    # FormatCodeTool has explicit tool_name "format_source_legacy"
    assert_tool_findable("format_source_legacy")
  end

  test "GitHubCreateIssueTool is findable" do
    # Test registry key (internal) - GitHubCreateIssueTool has tool_name "create_github_issue"
    assert_tool_findable("create_github_issue")

    # Test custom tool_name (MCP protocol) via session
    session = ActionMCP::Session.new(protocol_version: "2025-06-18")
    session.tool_registry = [ "create_github_issue" ] # Register by registry key
    registered_tools = session.registered_tools

    # Find tool by its MCP protocol name
    tool_class = registered_tools.find { |t| t.tool_name == "create_github_issue" }
    assert_not_nil tool_class, "Tool with tool_name 'create_github_issue' should be findable via session"

    # Execute tool
    tool = tool_class.new(title: "Test Issue", body: "Test body", labels: [ "bug" ])
    result = tool.call
    assert_match(/Issue created:/, result.contents.first.text)
  end

  # Prompts
  test "AnalyzeCodePrompt is findable" do
    assert_prompt_findable("analyze_code")
  end

  test "SummarizeTextPrompt is findable" do
    assert_prompt_findable("summarize_text")
    result = execute_prompt("analyze_code", language: "Ruby", code: "def hello; puts 'Hello, world!'; end")
    assert_prompt_output(
      [ { role: "user",
         content: { type: "text", text: "The code you provided is written in Ruby and looks great!" } } ], result
    )
  end
end
