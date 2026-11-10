# frozen_string_literal: true

require "test_helper"

class ProtocolVersionHeaderTest < ActionDispatch::IntegrationTest
  include SessionFixtureHelper
  fixtures :action_mcp_sessions

  def setup
    @valid_initialize_request = {
      jsonrpc: "2.0",
      id: "test-init-1",
      method: "initialize",
      params: {
        protocolVersion: "2025-11-25",
        capabilities: {
          roots: {
            listChanged: false
          }
        },
        clientInfo: {
          name: "TestClient",
          version: "1.0.0"
        }
      }
    }
  end

  test "accepts valid MCP-Protocol-Version header" do
    session = create_initialized_session

    mcp_post("tools/list", id: "test-1", session_id: session.id, protocol_version: "2025-11-25")

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
  end

  test "rejects unsupported MCP-Protocol-Version header" do
    session = create_initialized_session

    mcp_post("tools/list", id: "test-1", session_id: session.id, protocol_version: "2024-01-01")

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
    assert_includes json_response["error"]["message"], "Unsupported MCP-Protocol-Version"
    assert_includes json_response["error"]["message"], "2024-01-01"
  end

  test "rejects a present blank MCP-Protocol-Version header" do
    session = create_initialized_session

    mcp_post("tools/list", id: "blank-version", session_id: session.id, protocol_version: "   ")

    assert_response :bad_request
    assert_equal "blank-version", response.parsed_body["id"]
    assert_includes response.parsed_body.dig("error", "message"), "Unsupported MCP-Protocol-Version"
  end

  test "uses the negotiated session version when the header is missing" do
    session = create_initialized_session

    mcp_post("tools/list", id: "test-1", session_id: session.id)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
  end

  test "skips validation for initialize requests" do
    mcp_send(@valid_initialize_request, protocol_version: "1999-01-01")

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-init-1", json_response["id"]
  end

  test "handles case-insensitive header names" do
    session = create_initialized_session

    mcp_post("tools/list", id: "test-1", session_id: session.id,
                           headers: { "mcp-protocol-version" => "2025-11-25" })

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
  end
end
