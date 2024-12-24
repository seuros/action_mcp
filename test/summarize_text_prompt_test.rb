# frozen_string_literal: true

require "test_helper"

class SummarizeTextPromptTest < ActiveSupport::TestCase
  # Test valid params
  test "returns a concise summary by default" do
    params = { text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit." }
    result = SummarizeTextPrompt.call(params)

    assert result.key?(:summary), "Expected result to include :summary"
    assert_match /\A\[CONCISE\]/, result[:summary], "Expected summary to start with '[CONCISE]'"
  end

  test "returns a detailed summary when style is 'detailed'" do
    params = { text: "Lorem ipsum dolor sit amet.", style: "detailed" }
    result = SummarizeTextPrompt.call(params)

    assert_match /\A\[DETAILED\]/, result[:summary], "Expected summary to start with '[DETAILED]'"
  end

  # Test invalid params
  test "raises JsonRpcError if text is missing" do
    params = { style: "concise" } # Missing text

    error = assert_raises(ActionMCP::JsonRpc::JsonRpcError) do
      SummarizeTextPrompt.call(params)
    end

    # Verify error code, message, and data
    assert_equal(-32602, error.code, "Expected error code for invalid_params")
    assert_match(/Prompt validation failed/i, error.message)
    assert_includes error.data[:errors].to_hash, :text, "Expected :text to be in validation errors"
  end

  test "raises JsonRpcError if style is invalid" do
    params = { text: "Hello, world!", style: "unknown_style" }

    error = assert_raises(ActionMCP::JsonRpc::JsonRpcError) do
      SummarizeTextPrompt.call(params)
    end

    assert_equal(-32602, error.code)
    assert_match(/Prompt validation failed/i, error.message)
    assert_includes error.data[:errors].to_hash, :style
  end

  # Directly test the instance call method
  test "instance call returns concise summary" do
    prompt = SummarizeTextPrompt.new(text: "Hello world")
    # Validate the model (raises ActiveModel::ValidationError if invalid)
    prompt.validate!

    result = prompt.call
    assert_match /\A\[CONCISE\]/, result[:summary]
  end
end
