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
      assert_equal "2025-03-26", payload[:protocolVersion]
      assert_equal "ActionMCP Dummy", payload[:serverInfo]["name"]
      assert_equal "9.9.9", payload[:serverInfo]["version"]

      # Verify expected capabilities are present
      capabilities = payload[:capabilities]
      assert capabilities.key?("tools")
      assert capabilities.key?("prompts")
      assert capabilities.key?("resources")
      assert capabilities.key?("logging")
    end

    test "with custom profile " do
      ActionMCP.with_profile(:minimal) do
        session = Session.create

        # Get the actual payload
        payload = session.server_capabilities_payload

        # Verify basic structure
        assert_equal "2025-03-26", payload[:protocolVersion]
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
  end
end
