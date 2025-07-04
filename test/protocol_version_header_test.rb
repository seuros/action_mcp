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
        protocolVersion: "2025-06-18",
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
    session = create_initialized_session("2025-06-18")

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "test-1",
        method: "tools/list"
      }.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "ACCEPT" => "application/json",
        "Mcp-Session-Id" => session.id,
        "MCP-Protocol-Version" => "2025-06-18"
      }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
  end

  test "rejects unsupported MCP-Protocol-Version header" do
    session = create_initialized_session

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "test-1",
        method: "tools/list"
      }.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "ACCEPT" => "application/json",
        "Mcp-Session-Id" => session.id,
        "MCP-Protocol-Version" => "2024-01-01"
      }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
    assert_includes json_response["error"]["message"], "Unsupported MCP-Protocol-Version"
    assert_includes json_response["error"]["message"], "2024-01-01"
  end

  test "handles missing MCP-Protocol-Version header with backward compatibility" do
    session = create_initialized_session

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "test-1",
        method: "tools/list"
      }.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "ACCEPT" => "application/json",
        "Mcp-Session-Id" => session.id
      }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
  end

  test "rejects version mismatch between header and negotiated version" do
    session = create_initialized_session

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "test-1",
        method: "tools/list"
      }.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "ACCEPT" => "application/json",
        "Mcp-Session-Id" => session.id,
        "MCP-Protocol-Version" => "2025-06-18"  # Different from session's negotiated version
      }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
    assert_includes json_response["error"]["message"], "does not match negotiated version"
  end

  test "skips validation for initialize requests" do
    post "/",
      params: @valid_initialize_request.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "ACCEPT" => "application/json",
        "MCP-Protocol-Version" => "2025-03-26"  # Should be ignored for initialize
      }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-init-1", json_response["id"]
  end

  test "handles case-insensitive header names" do
    session = create_initialized_session("2025-06-18")

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "test-1",
        method: "tools/list"
      }.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "ACCEPT" => "application/json",
        "Mcp-Session-Id" => session.id,
        "mcp-protocol-version" => "2025-06-18"  # lowercase version
      }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
  end

  private

  def create_initialized_session(protocol_version = "2025-03-26")
    # Get fixture data based on protocol version
    fixture_session = if protocol_version == "2025-06-18"
                        action_mcp_sessions(:dr_identity_mcbouncer_session)
    else
                        action_mcp_sessions(:step1_session)
    end

    # Create session in the session store using the helper
    session = ActionMCP::Server.session_store.create_session(
      fixture_session.id,
      session_payload_from_fixture(fixture_session)
    )
    session
  end

  def initialize_session
    post "/",
      params: @valid_initialize_request.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "ACCEPT" => "application/json"
      }

    assert_response :success

    # Get session ID from response header
    session_id = response.headers["Mcp-Session-Id"]
    assert_not_nil session_id

    @session = ActionMCP::Server.session_store.load_session(session_id)
    assert_not_nil @session
    assert @session.initialized?
  end
end
