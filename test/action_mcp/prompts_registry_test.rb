# frozen_string_literal: true

module ActionMCP
  class PromptsRegistryTest < ActiveSupport::TestCase
    test "fetch returns correct metadata" do
      metadata = PromptsRegistry.fetch("analyze-code")
      assert_equal AnalyzeCodePrompt, metadata[:class]
      assert metadata[:enabled]
    end

    test "size excludes abstract prompts" do
      # Only the concrete prompt should be counted.
      assert_equal PromptsRegistry.size, ActionMCP.prompts.size
    end

    test "enabled list excludes abstract prompts" do
      enabled_names = PromptsRegistry.enabled
      assert_includes enabled_names.keys, "analyze-code"
    end
  end
end
