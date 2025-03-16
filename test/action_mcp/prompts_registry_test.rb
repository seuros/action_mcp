# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class PromptsRegistryTest < ActiveSupport::TestCase
    test "fetch returns correct metadata" do
      prompt = PromptsRegistry.find("analyze_code")
      assert_equal AnalyzeCodePrompt, prompt
    end

    test "size excludes abstract prompts" do
      # Only the concrete prompt should be counted.
      assert_equal 4, ActionMCP.prompts.size
      assert_equal 4, PromptsRegistry.size
    end

    test "non_abstract list excludes abstract prompts" do
      non_abstract_names = PromptsRegistry.non_abstract
      assert_includes non_abstract_names.keys, "analyze_code"
    end

    test "prompt_call calls the prompt" do
      response = PromptsRegistry.prompt_call("analyze_code", { code: "puts 'hello world'" })
      assert_instance_of PromptResponse, response
      assert response.messages.size.positive?
      assert response.messages.first[:role].present?
      assert response.messages.first[:content].present?
      assert_equal "user", response.messages.first[:role]
    end
  end
end
