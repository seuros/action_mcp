# frozen_string_literal: true

require "active_support/testing/assertions"
require_relative "test_helper/session_store_assertions"
require_relative "test_helper/progress_notification_assertions"

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
  #               assert_mcp_resource_template_findable,
  #               execute_mcp_tool,
  #               execute_mcp_prompt,
  #               resolve_mcp_resource,
  #               assert_mcp_error_code,
  #               assert_mcp_tool_output,
  #               assert_mcp_prompt_output.
  #
  # Short alias names (without the prefix) remain for this gem’s own suite but
  # are *not* documented for public use.
  #---------------------------------------------------------------------------
  module TestHelper
    include ActiveSupport::Testing::Assertions
    include SessionStoreAssertions
    include ProgressNotificationAssertions

    # ──── Registry assertions ────────────────────────────────────────────────
    def assert_mcp_resource_template_findable(name, msg = nil)
      assert ActionMCP::ResourceTemplatesRegistry.resource_templates.key?(name),
             msg || "Resource template #{name.inspect} not found in ResourceTemplatesRegistry"
    end
    alias assert_resource_template_findable assert_mcp_resource_template_findable

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

    def execute_mcp_tool_with_error(name, args = {})
      ActionMCP::ToolsRegistry.tool_call(name, args)
    end
    alias execute_tool_with_error execute_mcp_tool_with_error

    def execute_mcp_prompt(name, args = {})
      resp = ActionMCP::PromptsRegistry.prompt_call(name, args)
      assert !resp.is_error, "Prompt #{name.inspect} returned error: #{resp.to_h[:message]}"
      resp
    end
    alias execute_prompt execute_mcp_prompt

    def resolve_mcp_resource(uri)
      template_class = ActionMCP::ResourceTemplatesRegistry.find_template_for_uri(uri)
      assert template_class, "No resource template found matching URI #{uri.inspect}"
      template = template_class.process(uri)
      assert template, "Failed to process URI #{uri.inspect} with template #{template_class.name}"
      resp = template.call
      assert !resp.is_error, "Resource #{uri.inspect} returned error: #{resp.to_h[:message]}"
      resp
    end
    alias resolve_resource resolve_mcp_resource

    def resolve_mcp_resource_with_error(uri)
      template_class = ActionMCP::ResourceTemplatesRegistry.find_template_for_uri(uri)
      return error_response(:invalid_params, message: "No resource template found matching URI: #{uri}") unless template_class

      template = template_class.process(uri)
      template.call
    end
    alias resolve_resource_with_error resolve_mcp_resource_with_error

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
