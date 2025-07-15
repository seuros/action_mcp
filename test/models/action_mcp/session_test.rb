# frozen_string_literal: true

# == Schema Information
#
# Table name: action_mcp_sessions
#
#  id                     :string           not null, primary key
#  authentication_method  :string           default("none")
#  client_capabilities    :json
#  client_info            :json
#  consents               :json             not null
#  ended_at               :datetime
#  initialized            :boolean          default(FALSE), not null
#  messages_count         :integer          default(0), not null
#  oauth_access_token     :string
#  oauth_refresh_token    :string
#  oauth_token_expires_at :datetime
#  oauth_user_context     :json
#  prompt_registry        :json
#  protocol_version       :string
#  resource_registry      :json
#  role                   :string           default("server"), not null
#  server_capabilities    :json
#  server_info            :json
#  sse_event_counter      :integer          default(0), not null
#  status                 :string           default("pre_initialize"), not null
#  tool_registry          :json
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_action_mcp_sessions_on_authentication_method   (authentication_method)
#  index_action_mcp_sessions_on_oauth_access_token      (oauth_access_token) UNIQUE
#  index_action_mcp_sessions_on_oauth_token_expires_at  (oauth_token_expires_at)
#
require "test_helper"

module ActionMCP
  class SessionTest < ActiveSupport::TestCase
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
