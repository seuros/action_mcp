# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class MessagesControllerTest < ActionDispatch::IntegrationTest
    def setup
      @session = Session.create!
    end

    test "create should handle valid post message" do
      params = {
        jsonrpc: "2.0",
        id: 1,
        method: "test_method",
        params: { key: "value" }
      }

      post action_mcp.sse_in_url(session_id: @session.id), params: params

      assert_response :accepted
    end

    test "create should handle initialize message" do
      params = {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2024-11-05",
          clientInfo: {
            name: "test-client",
            version: "1.0.1"
          },
          capabilities: {
            roots: { listChanged: true },
            sampling: {}
          }
        }
      }

      post action_mcp.sse_in_url(session_id: @session.id), params: params

      assert_response :accepted
      assert @session.reload.initialized?
    end
  end
end
