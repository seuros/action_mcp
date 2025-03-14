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
  end
end
