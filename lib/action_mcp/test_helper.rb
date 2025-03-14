require "active_support/testing/assertions"

module ActionMCP
  module TestHelper
    include ActiveSupport::Testing::Assertions

    def assert_tool_findable(tool_name)
      assert ActionMCP::ToolsRegistry.tools.key?(tool_name), "Tool #{tool_name} not found in registry"
    end

    def assert_prompt_findable(prompt_name)
      assert ActionMCP::PromptsRegistry.prompts.key?(prompt_name), "Prompt #{prompt_name} not found in registry"
    end

    def execute_tool(tool_name, args = {})
      result = ActionMCP::ToolsRegistry.tool_call(tool_name, args)
      assert_equal false, result[:isError], "Tool #{tool_name} returned an error: #{result[:content].map(&:text).join(', ')}" if result[:isError]
      result
    end

    def execute_prompt(prompt_name, args = {})
      result = ActionMCP::PromptsRegistry.prompt_call(prompt_name, args)
       assert_equal false, result[:isError], "Prompt #{prompt_name} returned an error: #{result[:content].map(&:text).join(', ')}" if result[:isError]
      result
    end

    def assert_tool_output(result, expected_output)
       assert_equal expected_output, result[:content][0].text
    end

    def assert_prompt_output(result)
      assert_equal "user", result[:messages][0][:role]
      result[:messages][0][:content]
    end

    # Add more assertion methods as needed
  end
end
