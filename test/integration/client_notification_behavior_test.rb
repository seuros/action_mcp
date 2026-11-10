# frozen_string_literal: true

require "test_helper"

class ClientNotificationBehaviorTest < ActionDispatch::IntegrationTest
  PROTOCOL_VERSION = "2025-11-25"

  test "roots list change returns empty 202 and retains the generated roots request" do
    post_json(
      {
        jsonrpc: "2.0",
        id: "initialize",
        method: "initialize",
        params: {
          protocolVersion: PROTOCOL_VERSION,
          capabilities: { roots: { listChanged: true } },
          clientInfo: { name: "notification-test", version: "1.0.0" }
        }
      }
    )
    session_id = response.headers["Mcp-Session-Id"]
    assert_response :ok

    post_json(
      { jsonrpc: "2.0", method: "notifications/initialized" },
      session_id: session_id
    )
    assert_response :accepted

    post_json(
      { jsonrpc: "2.0", method: "notifications/roots/list_changed" },
      session_id: session_id
    )

    assert_response :accepted
    assert_empty response.body
    session = ActionMCP::Server.session_store.load_session(session_id)
    assert session.messages.any? { |message| rpc_method(message) == "roots/list" }
  end

  private

  def post_json(payload, session_id: nil)
    mcp_send(payload, session_id: session_id, protocol_version: (PROTOCOL_VERSION if session_id))
  end

  def rpc_method(message)
    data = message.respond_to?(:data) ? message.data : message[:data]
    data = data.to_h if data.respond_to?(:to_h)
    data[:method] || data["method"] if data.is_a?(Hash)
  end
end
