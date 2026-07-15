# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class SessionTest < ActiveSupport::TestCase
    setup do
      # Ensure configuration is properly loaded before creating sessions
      ActionMCP.configuration.name = "ActionMCP Dummy"
    end
    test "server capability payload" do
      session = Session.create

      # Get the actual payload
      payload = session.server_capabilities_payload

      # Verify basic structure
      assert_equal "2025-11-25", payload[:protocolVersion]
      assert_equal "ActionMCP Dummy", payload[:serverInfo]["name"]
      assert_equal "9.9.9", payload[:serverInfo]["version"]

      # Verify expected capabilities are present
      capabilities = payload[:capabilities]
      assert capabilities.key?("tools")
      assert capabilities.key?("prompts")
      assert capabilities.key?("resources")
      # Note: logging capability is not present when disabled by default
    end

    test "with custom profile " do
      ActionMCP.with_profile(:minimal) do
        session = Session.create

        # Get the actual payload
        payload = session.server_capabilities_payload

        # Verify basic structure
        assert_equal "2025-11-25", payload[:protocolVersion]
        assert_equal "ActionMCP Dummy", payload[:serverInfo]["name"]
        assert_equal "9.9.9", payload[:serverInfo]["version"]

        # With minimal profile, most capabilities should be empty
        capabilities = payload[:capabilities]
        refute capabilities.key?("tools")
        refute capabilities.key?("prompts")
        refute capabilities.key?("resources")

        # Any remaining capabilities are acceptable
      end
    end
    test "consent management" do
      session = Session.create

      # Initially no consent
      assert_not session.consent_granted_for?("test_tool")

      # Grant consent
      session.grant_consent("test_tool")
      assert session.consent_granted_for?("test_tool")

      # Revoke consent
      session.revoke_consent("test_tool")
      assert_not session.consent_granted_for?("test_tool")

      # Grant multiple consents
      session.grant_consent("tool1")
      session.grant_consent("tool2")
      assert session.consent_granted_for?("tool1")
      assert session.consent_granted_for?("tool2")

      # Revoke non-existent consent (should do nothing)
      session.revoke_consent("non_existent")
      assert session.consent_granted_for?("tool1")
    end

    test "server_capabilities_payload includes instructions at top level" do
      # Set up configuration with instructions
      ActionMCP.configuration.server_instructions = [ "Use this server for testing", "Helpful for development" ]

      session = Session.create

      # Get the actual payload
      payload = session.server_capabilities_payload

      # Verify instructions are at top level as joined string
      assert_equal "Use this server for testing\nHelpful for development", payload[:instructions]
      # serverInfo should not contain instructions
      refute session.server_info.key?("instructions")
    end

    test "server_capabilities_payload omits instructions when not configured" do
      # Ensure no instructions are configured
      ActionMCP.configuration.server_instructions = []

      session = Session.create

      # Get the actual payload
      payload = session.server_capabilities_payload

      # Verify instructions are not present
      refute payload.key?(:instructions)
    end

    test "server_capabilities_payload includes tasks for 2025-11-25" do
      session = Session.create!(
        protocol_version: "2025-11-25",
        server_capabilities: {
          tools: { listChanged: true },
          tasks: { list: {}, cancel: {}, requests: { tools: { call: {} } } }
        }
      )

      capabilities = session.server_capabilities_payload[:capabilities]
      assert capabilities.key?("tasks")
    end

    test "server_capabilities_payload includes mcp apps extension when configured" do
      original_mcp_apps_enabled = ActionMCP.configuration.mcp_apps_enabled
      ActionMCP.configuration.mcp_apps_enabled = true

      session = Session.create!
      capabilities = session.server_capabilities_payload[:capabilities]
      extensions = capabilities["extensions"] || capabilities[:extensions]

      assert_equal(
        { "mimeTypes" => [ ActionMCP::MIME_TYPE_APP_HTML ] },
        (extensions[ActionMCP::Apps::EXTENSION_KEY] || {}).deep_stringify_keys
      )
    ensure
      ActionMCP.configuration.mcp_apps_enabled = original_mcp_apps_enabled
    end

    test "register_tool is a no-op on wildcard registry" do
      session = Session.create
      assert_equal [ "*" ], session.tool_registry

      tool_count = session.registered_tools.count
      assert tool_count > 1

      session.register_tool(session.registered_tools.first.tool_name)
      assert_equal [ "*" ], session.tool_registry
      assert_equal tool_count, session.registered_tools.count
    end

    test "unregister_tool expands wildcard before removing" do
      session = Session.create
      assert_equal [ "*" ], session.tool_registry

      all_tools = session.registered_tools
      tool_to_remove = all_tools.first.tool_name

      session.unregister_tool(tool_to_remove)
      refute_includes session.tool_registry, "*"
      refute_includes session.tool_registry, tool_to_remove
      assert_equal all_tools.count - 1, session.registered_tools.count
    end

    test "unregister_tool preserves wildcard when tool does not exist" do
      session = Session.create
      assert_equal [ "*" ], session.tool_registry

      session.unregister_tool("nonexistent_tool_xyz")
      assert_equal [ "*" ], session.tool_registry
      assert session.uses_all_tools?
    end

    test "register_tool works normally on explicit registry" do
      session = Session.create
      session.tool_registry = []
      session.save!

      tool_name = ActionMCP.configuration.filtered_tools.first.name
      assert session.register_tool(tool_name)
      assert_includes session.tool_registry, tool_name
      assert_equal 1, session.registered_tools.count
    end
  end
end
