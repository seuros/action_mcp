require "test_helper"

module ActionMCP
  class SessionTest < ActiveSupport::TestCase
    test "server capability payload" do
      session = Session.create

      assert_equal({ protocolVersion: "2024-11-05",
                     serverInfo: { "name" => "ActionMCP Dummy", "version" => "9.9.9" },
                     capabilities: { "tools" => { "listChanged" => false },
                                     "prompts" => { "listChanged" => false },
                                     "resources" => {},
                                     "logging" => {}
                     } },
                   session.server_capabilities_payload)
    end
  end
end
