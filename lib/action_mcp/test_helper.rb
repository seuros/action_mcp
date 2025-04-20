# frozen_string_literal: true

require "active_support/testing/assertions"

module ActionMCP
  #---------------------------------------------------------------------------
  # ActionMCP::TestHelper
  #
  # Include in any `ActiveSupport::TestCase`:
  #
  #   include ActionMCP::TestHelper
  #
  # and you get   assert_mcp_tool_findable,
  #               assert_mcp_prompt_findable,
  #               execute_mcp_tool,
  #               execute_mcp_prompt,
  #               assert_mcp_error_code,
  #               assert_mcp_tool_output,
  #               assert_mcp_prompt_output.
  #
  # Short alias names (without the prefix) remain for this gem’s own suite but
  # are *not* documented for public use.
  #---------------------------------------------------------------------------
  module TestHelper
    include ActiveSupport::Testing::Assertions

    # ──── Registry assertions ────────────────────────────────────────────────
    def assert_mcp_tool_findable(name, msg = nil)
      assert ActionMCP::ToolsRegistry.tools.key?(name),
             msg || "Tool #{name.inspect} not found in ToolsRegistry"
    end
    alias assert_tool_findable assert_mcp_tool_findable

    def assert_mcp_prompt_findable(name, msg = nil)
      assert ActionMCP::PromptsRegistry.prompts.key?(name),
             msg || "Prompt #{name.inspect} not found in PromptsRegistry"
    end
    alias assert_prompt_findable assert_mcp_prompt_findable

    # ──── Execution helpers (happy‑path only) ────────────────────────────────
    def execute_mcp_tool(name, args = {})
      resp = ActionMCP::ToolsRegistry.tool_call(name, args)
      assert !resp.is_error, "Tool #{name.inspect} returned error: #{resp.to_h[:message]}"
      resp
    end
    alias execute_tool execute_mcp_tool

    def execute_mcp_prompt(name, args = {})
      resp = ActionMCP::PromptsRegistry.prompt_call(name, args)
      assert !resp.is_error, "Prompt #{name.inspect} returned error: #{resp.to_h[:message]}"
      resp
    end
    alias execute_prompt execute_mcp_prompt

    # ──── Negative‑path helper ───────────────────────────────────────────────
    def assert_mcp_error_code(code, response, msg = nil)
      assert response.error?, msg || "Expected response to be an error"
      assert_equal code, response.to_h[:code],
                   msg || "Expected error code #{code}, got #{response.to_h[:code]}"
    end
    alias assert_error_code assert_mcp_error_code

    # ──── Output assertions ─────────────────────────────────────────────────
    def assert_mcp_tool_output(expected, response, msg = nil)
      assert response.success?, msg || "Expected a successful tool response"
      assert_equal expected, response.contents.map(&:to_h),
                   msg || "Tool output did not match expected"
    end
    alias assert_tool_output assert_mcp_tool_output

    def assert_mcp_prompt_output(expected, response, msg = nil)
      assert response.success?, msg || "Expected a successful prompt response"
      assert_equal expected, response.messages,
                   msg || "Prompt output did not match expected"
    end
    alias assert_prompt_output assert_mcp_prompt_output
  end
end
