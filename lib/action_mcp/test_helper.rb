require "active_support/testing/assertions"

module ActionMCP
  module TestHelper
    include ActiveSupport::Testing::Assertions

    # Asserts that a tool is findable in the ToolsRegistry.
    # @param [String] tool_name
    def assert_tool_findable(tool_name)
      assert ActionMCP::ToolsRegistry.tools.key?(tool_name), "Tool #{tool_name} not found in registry"
    end

    # Asserts that a prompt is findable in the PromptsRegistry.
    # @param [String] prompt_name
    def assert_prompt_findable(prompt_name)
      assert ActionMCP::PromptsRegistry.prompts.key?(prompt_name), "Prompt #{prompt_name} not found in registry"
    end

    # Executes a tool with the given name and arguments.
    # @param [String] tool_name
    # @param [Hash] args
    def execute_tool(tool_name, args = {})
      result = ActionMCP::ToolsRegistry.tool_call(tool_name, args)
      assert_not result.is_error, "Tool #{tool_name} returned an error: #{result.to_h[:message]}"
      result
    end

    # Executes a prompt with the given name and arguments.
    # @param [String] prompt_name
    # @param [Hash] args
    def execute_prompt(prompt_name, args = {})
      result = ActionMCP::PromptsRegistry.prompt_call(prompt_name, args)
      assert_not result.is_error, "Prompt #{prompt_name} returned an error: #{result.to_h[:message]}"
      result
    end

    # Asserts that the output of a tool is equal to the expected output.
    # @param [Hash] expected_output
    # @param [ActionMCP::ToolResponse] result
    def assert_tool_output(expected_output, result)
       assert_equal expected_output, result.to_h[:content], "Tool output did not match expected output #{expected_output} != #{result.to_h[:content]}"
    end

    # Asserts that the output of a prompt is equal to the expected output.
    # @param [Hash] expected_output
    # @param [ActionMCP::PromptResponse] result
    def assert_prompt_output(expected_output, result)
      assert_equal expected_output, result.to_h[:messages], "Prompt output did not match expected output #{expected_output} != #{result.to_h[:messages]}"
    end
  end
end
