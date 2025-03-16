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
end
