# frozen_string_literal: true

require "test_helper"

class GreetingPromptTest < ActiveSupport::TestCase
  test "generates a valid greeting response with required parameters" do
    # Arrange
    prompt = GreetingPrompt.new(name: "Ruby", style: "friendly")
    response = GreetingPrompt.logger.silence do
      # Act
      prompt.call # This executes the prompt
    end

    # Assert
    assert_equal 3, response.messages.size

    # Check the first message (user)
    assert_equal "user", response.messages[0][:role]
    assert_equal "Please create a greeting for Ruby", response.messages[0][:content][:text]
    # Check the second message (assistant)
    assert_equal "assistant", response.messages[1][:role]
    assert_equal "I'd be happy to create a friendly greeting for Ruby!", response.messages[1][:content][:text]

    # Check the third message (user)
    assert_equal "user", response.messages[2][:role]
    assert_equal "The greeting should be in friendly style.", response.messages[2][:content][:text]
  end

  test "validates required parameters" do
    # Arrange - missing required 'name' parameter
    prompt = GreetingPrompt.new(style: "formal")

    # Assert that the prompt is invalid
    assert_not prompt.valid?
    assert_includes prompt.errors.full_messages, "Name can't be blank"
    response = GreetingPrompt.logger.silence do
      # Make sure calling an invalid prompt works as expected
      prompt.call
    end
    assert_match(/can't be blank/, response.to_h[:data].first)
  end

  test "validates enum parameters" do
    # Arrange - invalid 'style' parameter
    prompt = GreetingPrompt.new(name: "Ruby", style: "super_casual")

    # Assert that the prompt is invalid
    assert_not prompt.valid?
    assert_includes prompt.errors.full_messages, "Style is not included in the list"
    response = GreetingPrompt.logger.silence do
      # Make sure calling an invalid prompt works as expected
      prompt.call
    end
    assert_match(/not included in the list/, response.to_h[:data].first)
  end

  test "uses default values when parameters are not provided" do
    # Arrange - missing optional 'style' parameter
    prompt = GreetingPrompt.new(name: "Ruby")

    response = GreetingPrompt.logger.silence do
      # Act
      prompt.call
    end

    # Assert - should use default "friendly" style
    assert_match(/friendly/, response.messages[1][:content][:text])
  end
end
