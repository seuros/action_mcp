# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class NamespacePromptsRegistryTest < ActiveSupport::TestCase
    setup do
      @original_prompts = PromptsRegistry.items.dup
      # Clear the registry before each test
      PromptsRegistry.clear!
    end

    teardown do
      PromptsRegistry.clear!
      ActionMCP::Prompt.descendants.each do |prompt_class|
        next if prompt_class.abstract?

        PromptsRegistry.register(prompt_class)
      end

      # Restore any prompts that might live outside the descendant list (defensive)
      @original_prompts.each do |name, klass|
        PromptsRegistry.items[name] ||= klass
      end
    end

    test "registers multiple prompts with same class name but different namespaces and no explicit prompt_name" do
      # The dummy app has Cat::GreetingPrompt and Dog::GreetingPrompt
      # Both have the same class name "WeatherPrompt" but different namespaces
      PromptsRegistry.register(Cat::GreetingPrompt)
      PromptsRegistry.register(Dog::GreetingPrompt)

      prompts = PromptsRegistry.prompts

      # Both prompts should be registered with their explicit prompt_names
      assert_includes prompts, "cat__greeting"
      assert_includes prompts, "dog__greeting"

      assert_equal Cat::GreetingPrompt, prompts["cat__greeting"]
      assert_equal Dog::GreetingPrompt, prompts["dog__greeting"]
    end

    test "prompt_call works with namespace prompts" do
      PromptsRegistry.register(Cat::GreetingPrompt)
      PromptsRegistry.register(Dog::GreetingPrompt)

      cat_response = PromptsRegistry.prompt_call("cat__greeting", { name: "Brandy" })
      dog_response = PromptsRegistry.prompt_call("dog__greeting", { name: "Mr. Whiskers" })

      assert_instance_of PromptResponse, cat_response
      assert_instance_of PromptResponse, dog_response

      refute cat_response.error?
      refute dog_response.error?
    end

    test "prompts are not overwritten when using same class names from different modules" do
      PromptsRegistry.register(Cat::GreetingPrompt)
      initial_count = PromptsRegistry.prompts.size

      PromptsRegistry.register(Dog::GreetingPrompt)
      final_count = PromptsRegistry.prompts.size

      # Registry size should increase by 1, not stay the same (this tests the bug)
      assert_equal initial_count + 1, final_count
    end

    test "prompts with explicit prompt_name override default_prompt_name" do
      alien = Alien::GreetingPrompt.new({})

      assert_equal "alien__greeting", alien.class.default_prompt_name

      assert_equal "alien_greeting", alien.class.prompt_name
    end

    test "prompts without an explicit prompt_name use their default_prompt_name" do
      dog = Dog::GreetingPrompt.new({})

      assert_equal "dog__greeting",       dog.class.prompt_name
      assert_equal dog.class.prompt_name, dog.class.default_prompt_name
    end
  end
end
