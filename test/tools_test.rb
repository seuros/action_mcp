# frozen_string_literal: true

require "test_helper"

class ToolsTest < ActiveSupport::TestCase
  test "AnalyzeCsvTool should return fake analysis results" do
    tool = AnalyzeCsvTool.new(filepath: "/path/to/file.csv", operations: %w[sum count])
    result = tool.call
    assert result.is_a?(ActionMCP::Content::Text)
    assert JSON.parse(result.text).keys.sort == %w[count sum]
  end

  test "CalculateSumWithPrecisionTool should return sum with given precision" do
    tool = CalculateSumWithPrecisionTool.new(a: 1.234, b: 2.345, precision: 3)
    result = tool.call
    assert result.is_a?(ActionMCP::Content::Text)
    assert_equal "3.579", result.text
  end

  test "ChecksumCheckerTool should validate file checksums" do
    tool = ChecksumCheckerTool.new(files: [ "test.txt" ])
    result = tool.call
    assert result.is_a?(ActionMCP::Content::Text)
    assert result.text == "[#{'test.txt'.hash}]"
  end

  test "ExecuteCommandTool should return a fake execution result" do
    tool = ExecuteCommandTool.new(command: "ls", args: [ "-l", "/home" ])
    result = tool.call
    assert result.is_a?(ActionMCP::Content::Text)
    assert_match(%r{Executed: ls -l /home}, result.text)
  end

  test "FormatCodeTool should format code by trimming extra spaces" do
    tool = FormatCodeTool.new(source_code: "  def test \n  end  ", language: "ruby", style: "default")
    result = tool.call
    assert result.is_a?(ActionMCP::Content::Text)
    assert_equal "def test end", result.text
  end

  test "GitHubCreateIssueTool should return a fake GitHub issue URL" do
    tool = GitHubCreateIssueTool.new(title: "Bug report", body: "Fix this issue", labels: [ "bug" ])
    result = tool.call
    assert result.is_a?(ActionMCP::Content::Text)
    assert_match %r{https://github.com/fake/repo/issues/\d+}, result.text
  end
end
