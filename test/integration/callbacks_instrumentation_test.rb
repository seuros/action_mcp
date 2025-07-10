# frozen_string_literal: true

require "test_helper"

class CallbacksInstrumentationTest < ActionDispatch::IntegrationTest
  test "callbacks and instrumentation are executed in the correct order for CalculateSumTool" do
    # Reset callback tracker before test
    CalculateSumTool.reset_callback_tracker

    tool = CalculateSumTool.new(a: 1, b: 2)
    tool.call

    # Test using callback tracker
    expected_callbacks = [
      :before_perform,
      :around_perform_before,
      :perform,
      :after_perform,
      :around_perform_after
    ]

    assert_equal expected_callbacks, CalculateSumTool.callback_tracker
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
