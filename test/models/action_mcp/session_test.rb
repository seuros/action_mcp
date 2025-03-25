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
#  protocol_version                                    :string
#  role(The role of the session)                       :string           default("server"), not null
#  server_capabilities(The capabilities of the server) :jsonb
#  server_info(The information about the server)       :jsonb
#  status                                              :string           default("pre_initialize"), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#
require "test_helper"

module ActionMCP
  class SessionTest < ActiveSupport::TestCase
    test "server capability payload" do
      session = Session.create

      assert_equal({ protocolVersion: "2024-11-05",
                     serverInfo: { "name" => "ActionMCP Dummy", "version" => "9.9.9" },
                     capabilities: { "tools" => { "listChanged" => false },
                                     "prompts" => { "listChanged" => false },
                                     "resources" => { "subscribe"=>false },
                                     "logging" => {} } },
                   session.server_capabilities_payload)
    end


    test "with custom profile " do
      ActionMCP.with_profile(:minimal) do
        session = Session.create

        assert_equal({ protocolVersion: "2024-11-05",
                       serverInfo: { "name" => "ActionMCP Dummy", "version" => "9.9.9" },
                       capabilities: {} },
                     session.server_capabilities_payload)
      end
    end
  end
end
