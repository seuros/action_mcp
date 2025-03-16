# frozen_string_literal: true

require "test_helper"

class SummarizeTextPromptTest < ActiveSupport::TestCase
  # Test valid params
  test "returns a concise summary by default" do
    params = { text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit." }
    result = SummarizeTextPrompt.new(params).call

    assert_match(/\A\[CONCISE\]/,  result.messages[0][:content][:text], "Expected summary to start with '[CONCISE]'")
  end

  test "returns a detailed summary when style is 'detailed'" do
    params = { text: "Lorem ipsum dolor sit amet.", style: "detailed" }
    result = SummarizeTextPrompt.new(params).call

    assert_match(/\A\[DETAILED\]/,  result.messages[0][:content][:text], "Expected summary to start with '[DETAILED]'")
  end

  test "returns error response for missing required text parameter" do
    # Arrange - missing required 'text' parameter
    prompt = SummarizeTextPrompt.new(style: "concise")

    # Assert that the prompt is invalid
    assert_not prompt.valid?

    # Act
    response = prompt.call

    # Assert - should return error response
    response_hash = response.to_h
    assert_equal(-32602, response_hash[:code])
    assert_includes response_hash[:data], "Text can't be blank"
    assert_equal "Invalid input", response_hash[:message]  end

  test "returns error response for empty text parameter" do
    # Arrange - empty 'text' parameter
    prompt = SummarizeTextPrompt.new(text: "", style: "concise")

    # Assert that the prompt is invalid
    assert_not prompt.valid?

    # Act
    response = prompt.call

    # Assert - should return error response
    response_hash = response.to_h
    assert_equal(-32602, response_hash[:code])
    assert_equal "Invalid input", response_hash[:message]
    assert_includes response_hash[:data], "Text can't be blank"
  end

  test "returns error response for invalid style enum value" do
    # Arrange - invalid 'style' parameter
    prompt = SummarizeTextPrompt.new(text: "This is some text to summarize", style: "invalid_style")

    # Assert that the prompt is invalid
    assert_not prompt.valid?

    # Act
    response = prompt.call

    # Assert - should return error response
    response_hash = response.to_h
    assert_equal(-32602, response_hash[:code])
    assert_includes response_hash[:data], "Style is not included in the list"
    assert_equal "Invalid input", response_hash[:message]
  end

  test "uses default style when style is not provided" do
    # Arrange - missing optional 'style' parameter
    prompt = SummarizeTextPrompt.new(text: "This is some text to summarize")

    # Assert that the prompt is valid (since style has a default)
    assert prompt.valid?

    # Act
    response = prompt.call
    response_hash = response.to_h

    # Assert - should not have an error
    assert_not response_hash.key?(:error), "Response should not contain an error key"

    # Should use default "concise" style
    assert_match /\[CONCISE\]/, response.messages.first[:content][:text]
  end

  test "handles very long text input" do
    # Arrange - extremely long text
    long_text = "a" * 10000
    prompt = SummarizeTextPrompt.new(text: long_text)

    # Act
    response = prompt.call
    response_hash = response.to_h

    # Assert - should not have an error
    assert_not response_hash.key?(:error), "Response should not contain an error key"

    # Should truncate in concise mode
    assert_match /\[CONCISE\]/, response.messages.first[:content][:text]
    assert response.messages.first[:content][:text].length < long_text.length
  end

  test "handles nil input for optional parameters" do
    # Arrange - nil for optional parameter
    prompt = SummarizeTextPrompt.new(text: "Sample text", style: nil)

    # Act
    response = prompt.call
    response_hash = response.to_h
    # Should fall back to default
    assert_match /\[CONCISE\]/, response_hash[:messages].first[:content][:text]
  end
end
