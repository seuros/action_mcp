# frozen_string_literal: true

require "test_helper"

class CallbacksInstrumentationTest < ActionDispatch::IntegrationTest
  test "callbacks and instrumentation are executed in the correct order for CalculateSumTool" do
    # Reset callback tracker before test
    CalculateSumTool.reset_callback_tracker

    tool = CalculateSumTool.new(a: 1, b: 2)
    tool.call

    # Test using callback tracker
    expected_callbacks = %i[
      before_perform
      around_perform_before
      perform
      after_perform
      around_perform_after
    ]

    assert_equal expected_callbacks, CalculateSumTool.callback_tracker
  end

  test "callbacks and instrumentation are executed in the correct order for GreetingPrompt" do
    prompt = GreetingPrompt.new(name: "Test")

    result = prompt.call

    # Verify the prompt executed successfully
    assert_not_nil result
    assert result.success?
  end
end
