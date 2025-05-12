# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class MessagesControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers
    def setup
      @session = Session.create!
    end

    def app
      ActionMCP::Engine
    end

    test "create should handle valid post message" do
      params = {
        jsonrpc: "2.0",
        id: 1,
        method: "test_method",
        params: { key: "value" }
      }

      post sse_in_path(session_id: @session.id), params: params

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

      post sse_in_path(session_id: @session.id), params: params

      assert_response :accepted
      assert @session.reload.initialized?
    end
  end
end
