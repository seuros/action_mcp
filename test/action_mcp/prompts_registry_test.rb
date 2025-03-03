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
      assert_equal PromptsRegistry.size, ActionMCP.prompts.size
    end

    test "non_abstract list excludes abstract prompts" do
      non_abstract_names = PromptsRegistry.non_abstract
      assert_includes non_abstract_names.keys, "analyze_code"
    end
  end
end
