# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ToolsRegistryTest < ActiveSupport::TestCase
    test "tool_call calls the prompt" do
      response = ToolsRegistry.tool_call("analyze_code", { code: "puts 'hello world'" })
      assert_instance_of ToolResponse, response
    end
  end
end
