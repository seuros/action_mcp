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

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-1",
           method: "tools/list"
         }.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream",
           "Mcp-Session-Id" => session.id,
           "MCP-Protocol-Version" => "2025-11-25"
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
           "ACCEPT" => "application/json, text/event-stream",
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

  test "rejects a present blank MCP-Protocol-Version header" do
    session = create_initialized_session

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "blank-version",
           method: "tools/list"
         }.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream",
           "Mcp-Session-Id" => session.id,
           "MCP-Protocol-Version" => "   "
         }

    assert_response :bad_request
    assert_equal "blank-version", response.parsed_body["id"]
    assert_includes response.parsed_body.dig("error", "message"), "Unsupported MCP-Protocol-Version"
  end

  test "uses the negotiated session version when the header is missing" do
    session = create_initialized_session

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-1",
           method: "tools/list"
         }.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream",
           "Mcp-Session-Id" => session.id
         }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
  end

  test "skips validation for initialize requests" do
    post "/",
         params: @valid_initialize_request.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream",
           "MCP-Protocol-Version" => "1999-01-01" # Only initialize params participate in negotiation
         }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-init-1", json_response["id"]
  end

  test "handles case-insensitive header names" do
    session = create_initialized_session

    post "/",
         params: {
           jsonrpc: "2.0",
           id: "test-1",
           method: "tools/list"
         }.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream",
           "Mcp-Session-Id" => session.id,
           "mcp-protocol-version" => "2025-11-25" # lowercase header name
         }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "2.0", json_response["jsonrpc"]
    assert_equal "test-1", json_response["id"]
  end

  private

  def create_initialized_session
    fixture_session = action_mcp_sessions(:step1_session)
    # Create session in the session store using the helper
    ActionMCP::Server.session_store.create_session(
      fixture_session.id,
      session_payload_from_fixture(fixture_session)
    )
  end

  def initialize_session
    post "/",
         params: @valid_initialize_request.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream"
         }

    assert_response :success

    # Get session ID from response header
    session_id = response.headers["Mcp-Session-Id"]
    assert_not_nil session_id

    @session = ActionMCP::Server.session_store.load_session(session_id)
    assert_not_nil @session
    refute @session.initialized?
    assert_equal "initializing", @session.status
  end
end
