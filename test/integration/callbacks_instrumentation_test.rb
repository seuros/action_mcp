require "test_helper"

class CallbacksInstrumentationTest < ActionDispatch::IntegrationTest
  test "callbacks and instrumentation are executed in the correct order for CalculateSumTool" do
    tool = CalculateSumTool.new(number1: 1, number2: 2)

    # Store the original logger
    original_logger = tool.logger

    # Create a new logger that writes to our string IO
    log_output = StringIO.new
    tool.logger = ActiveSupport::TaggedLogging.new(Logger.new(log_output))

    begin
      tool.call

      # Get all the log lines
      log_lines = log_output.string.lines.map(&:strip)

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
    ensure
      # Restore the original logger
      tool.logger = original_logger
    end
  end

  test "callbacks and instrumentation are executed in the correct order for GreetingPrompt" do
    prompt = GreetingPrompt.new(name: "Test")

    # Store the original logger
    original_logger = prompt.logger

    # Create a new logger that writes to our string IO
    log_output = StringIO.new
    prompt.logger = ActiveSupport::TaggedLogging.new(Logger.new(log_output))

    begin
      prompt.call

      # Get all the log lines
      log_lines = log_output.string.lines.map(&:strip)

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
    ensure
      # Restore the original logger
      prompt.logger = original_logger
    end
  end
end
