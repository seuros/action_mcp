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
    assert_tool_findable("format_source")
  end

  test "GitHubCreateIssueTool is findable" do
    assert_tool_findable("create_github_issue")
  end

  # Prompts
  test "AnalyzeCodePrompt is findable" do
    assert_prompt_findable("analyze_code")
  end

  test "SummarizeTextPrompt is findable" do
    assert_prompt_findable("summarize_text")
    result = execute_prompt("analyze_code", language: "Ruby", code: "def hello; puts 'Hello, world!'; end")
    assert_prompt_output([ { role: "user", content: { type: "text", text: "The code you provided is written in Ruby and looks great!" } } ], result)
  end
end
