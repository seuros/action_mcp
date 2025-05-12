# frozen_string_literal: true

# == Schema Information
#
# Table name: action_mcp_sessions
#
#  id                                                  :string           not null, primary key
#  client_capabilities(The capabilities of the client) :jsonb
#  client_info(The information about the client)       :jsonb
#  ended_at(The time the session ended)                :datetime
#  initialized                                         :boolean          default(FALSE), not null
#  messages_count                                      :integer          default(0), not null
#  prompt_registry                                     :jsonb
#  protocol_version                                    :string
#  resource_registry                                   :jsonb
#  role(The role of the session)                       :string           default("server"), not null
#  server_capabilities(The capabilities of the server) :jsonb
#  server_info(The information about the server)       :jsonb
#  sse_event_counter                                   :integer          default(0), not null
#  status                                              :string           default("pre_initialize"), not null
#  tool_registry                                       :jsonb
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#
require "test_helper"

module ActionMCP
  class SessionTest < ActiveSupport::TestCase
    test "server capability payload" do
      session = Session.create

      # Get the actual payload
      payload = session.server_capabilities_payload

      # Verify basic structure
      assert_equal "2024-11-05", payload[:protocolVersion]
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
        assert_equal "2024-11-05", payload[:protocolVersion]
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
  end
end
