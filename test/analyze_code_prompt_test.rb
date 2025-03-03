# frozen_string_literal: true

require "test_helper"

class AnalyzeCodePromptTest < ActiveSupport::TestCase
  test "to_h returns correct hash representation without default values" do
    prompt = AnalyzeCodePrompt

    expected_hash = {
      name: "analyze_code",
      description: "Analyze code for potential improvements",
      arguments: [
        { name: "language", description: "Programming language", required: false },
        { name: "code", description: "Code to explain", required: true }
      ]
    }

    assert_equal expected_hash, prompt.to_h
  end

  test "language validation works correctly" do
    prompt = AnalyzeCodePrompt.new(code: "print 'Hello, world!'", language: "PHP")
    assert_not prompt.valid?, "Prompt should be invalid with language 'PHP'"
    assert_includes prompt.errors[:language], "is not included in the list"

    # Changing language to an allowed value should make it valid.
    prompt.language = "Cobol"
    assert prompt.valid?, "Prompt should be valid with language 'Cobol'"
  end
end
