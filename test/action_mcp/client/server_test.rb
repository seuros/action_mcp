# frozen_string_literal: true

require 'minitest/autorun'

module ActionMCP
  module Client
    class ServerTest < ActiveSupport::TestCase
      test "server with full capabilities and dynamic flags enabled" do
        data = {
          "protocolVersion" => "2024-11-05",
          "serverInfo" => { "name" => "ActionMCP Dummy", "version" => "9.9.9" },
          "capabilities" => {
            "tools" => { "listChanged" => true },
            "prompts" => { "listChanged" => false },
            "logging" => {},
            "resources" => { "listChanged" => true }
          }
        }
        server = Server.new(data)

        assert_equal "ActionMCP Dummy", server.name
        assert_equal "9.9.9", server.version

        assert server.tools?, "Expected tools? to be true"
        assert server.prompts?, "Expected prompts? to be true"
        assert server.logging?, "Expected logging? to be true"
        assert server.resources?, "Expected resources? to be true"
        assert server.dynamic_tools?, "Expected dynamic_tools? to be true"
        assert server.dynamic_resources?, "Expected dynamic_resources? to be true"
      end

      test "server with full capabilities and non-dynamic flags" do
        data = {
          "protocolVersion" => "2024-11-05",
          "serverInfo" => { "name" => "ActionMCP Dummy", "version" => "9.9.9" },
          "capabilities" => {
            "tools" => { "listChanged" => false },
            "prompts" => { "listChanged" => false },
            "logging" => {},
            "resources" => { "listChanged" => false }
          }
        }
        server = Server.new(data)

        assert_equal "ActionMCP Dummy", server.name
        assert_equal "9.9.9", server.version

        assert server.tools?, "Expected tools? to be true"
        assert server.prompts?, "Expected prompts? to be true"
        assert server.logging?, "Expected logging? to be true"
        assert server.resources?, "Expected resources? to be true"
        refute server.dynamic_tools?, "Expected dynamic_tools? to be false"
        refute server.dynamic_resources?, "Expected dynamic_resources? to be false"
      end

      test "server with empty capabilities hash" do
        data = {
          "protocolVersion" => "2024-11-05",
          "serverInfo" => { "name" => "ActionMCP Dummy", "version" => "9.9.9" },
          "capabilities" => {}
        }
        server = Server.new(data)

        assert_equal "ActionMCP Dummy", server.name
        assert_equal "9.9.9", server.version

        refute server.tools?, "Expected tools? to be false when capabilities are empty"
        refute server.prompts?, "Expected prompts? to be false when capabilities are empty"
        refute server.logging?, "Expected logging? to be false when capabilities are empty"
        refute server.resources?, "Expected resources? to be false when capabilities are empty"
        refute server.dynamic_tools?, "Expected dynamic_tools? to be false when capabilities are empty"
        refute server.dynamic_resources?, "Expected dynamic_resources? to be false when capabilities are empty"
      end

      test "server with no capabilities key provided" do
        data = {
          "protocolVersion" => "2024-11-05",
          "serverInfo" => { "name" => "ActionMCP Dummy", "version" => "9.9.9" }
          # No 'capabilities' key is present
        }
        server = Server.new(data)

        assert_equal "ActionMCP Dummy", server.name
        assert_equal "9.9.9", server.version

        refute server.tools?, "Expected tools? to be false when capabilities key is missing"
        refute server.prompts?, "Expected prompts? to be false when capabilities key is missing"
        refute server.logging?, "Expected logging? to be false when capabilities key is missing"
        refute server.resources?, "Expected resources? to be false when capabilities key is missing"
        refute server.dynamic_tools?, "Expected dynamic_tools? to be false when capabilities key is missing"
        refute server.dynamic_resources?, "Expected dynamic_resources? to be false when capabilities key is missing"
      end
    end
  end
end
