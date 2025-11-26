# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class PromptReregistrationTest < ActiveSupport::TestCase
    setup do
      @original_prompts = PromptsRegistry.items.dup
      PromptsRegistry.clear!
    end

    teardown do
      PromptsRegistry.clear!
      @original_prompts.each do |name, klass|
        PromptsRegistry.items[name] = klass
        klass._registered_name = name if klass.respond_to?(:_registered_name=)
      end
    end

    test "_registered_name is set after registration" do
      PromptsRegistry.register(Cat::GreetingPrompt)

      assert_equal "cat__greeting", Cat::GreetingPrompt._registered_name
    end

    test "re_register removes old entry and adds new entry" do
      # Use an existing concrete prompt class instead of creating a new one
      # that would auto-register and pollute the registry
      test_prompt = Cat::GreetingPrompt

      # Manually register under wrong name to simulate timing issue
      PromptsRegistry.items["wrong_prompt_name"] = test_prompt
      test_prompt._registered_name = "wrong_prompt_name"

      # Now call re_register
      PromptsRegistry.re_register(test_prompt, "wrong_prompt_name")

      # Old entry should be gone
      refute_includes PromptsRegistry.prompts.keys, "wrong_prompt_name"
      # New entry should exist under its canonical name
      assert_includes PromptsRegistry.prompts.keys, "cat__greeting"
      assert_equal "cat__greeting", test_prompt._registered_name
    end

    test "re-registration is idempotent" do
      PromptsRegistry.register(Cat::GreetingPrompt)
      initial_size = PromptsRegistry.prompts.size

      # Calling prompt_name again with same value should not duplicate
      Cat::GreetingPrompt.prompt_name("cat__greeting")

      assert_equal initial_size, PromptsRegistry.prompts.size
    end

    test "abstract prompts are not re-registered" do
      initial_size = PromptsRegistry.prompts.size

      PromptsRegistry.re_register(ApplicationMCPPrompt, "some_name")

      assert_equal initial_size, PromptsRegistry.prompts.size
    end
  end
end
