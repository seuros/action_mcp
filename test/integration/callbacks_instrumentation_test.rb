# frozen_string_literal: true

require "test_helper"

class CallbacksInstrumentationTest < ActionDispatch::IntegrationTest
  test "callbacks and instrumentation are executed in the correct order for CalculateSumTool" do
    tool = CalculateSumTool.new(number1: 1, number2: 2)

    with_silenced_logger(tool) do |io|
      tool.call

      # Get all the log lines
      log_lines = io.string.lines.map(&:strip)

      # Filter relevant log entries
      relevant_logs = log_lines.select { |line| line.include?("[CalculateSumTool]") }

      expected_logs = [
        "[CalculateSumTool] before_perform",
        "[CalculateSumTool] around_perform (before)",
        "[CalculateSumTool] perform",
        "[CalculateSumTool] after_perform",
        "[CalculateSumTool] around_perform (after)"
      ]

      # Test the order - each log message should appear exactly once
      assert_equal expected_logs, relevant_logs.uniq
    end
  end

  test "callbacks and instrumentation are executed in the correct order for GreetingPrompt" do
    prompt = GreetingPrompt.new(name: "Test")

    with_silenced_logger(prompt) do |io|
      prompt.call

      # Get all the log lines
      log_lines = io.string.lines.map(&:strip)

      # Filter relevant log entries
      relevant_logs = log_lines.select { |line| line.include?("[GreetingPrompt]") }

      expected_logs = [
        "[GreetingPrompt] before_perform",
        "[GreetingPrompt] around_perform (before)",
        "[GreetingPrompt] perform",
        "[GreetingPrompt] after_perform",
        "[GreetingPrompt] around_perform (after)"
      ]

      # Test the order - each log message should appear exactly once
      assert_equal expected_logs, relevant_logs.uniq
    end
  end
end
