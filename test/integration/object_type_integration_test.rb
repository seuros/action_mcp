# frozen_string_literal: true

require "test_helper"

class ObjectTypeIntegrationTest < ActionDispatch::IntegrationTest
  include ActionMCP::TestHelper

  setup do
    @protocol_version = ActionMCP::LATEST_VERSION
    @session_id = nil
    setup_mcp_session
  end

  test "handles object type correctly through JSON-RPC" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "update_config",
             arguments: {
               config: {
                 "database" => {
                   "host" => "localhost",
                   "port" => 5432
                 },
                 "cache_ttl" => 3600
               }
             }
           }
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"], "Expected no error, got: #{response_data['error']}"
    assert response_data["result"]
    assert_match(/Updated config: database\.host=localhost/, response_data["result"]["content"].first["text"])
  end

  test "rejects string as object via JSON-RPC" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: 2,
           method: "tools/call",
           params: {
             name: "update_config",
             arguments: {
               config: "not an object"
             }
           }
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert response_data["error"], "Expected error for string input"
    assert_equal(-32_602, response_data["error"]["code"])
    assert_match(/Parameter 'config' must be an object\/hash/, response_data["error"]["message"])
  end

  test "rejects null for required object via JSON-RPC" do
    post "/",
         params: {
           jsonrpc: "2.0",
           id: 6,
           method: "tools/call",
           params: {
             name: "update_config",
             arguments: {
               config: nil
             }
           }
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert response_data["error"], "Expected error for null input"
    assert_equal(-32_602, response_data["error"]["code"])
    # Nil is caught by type validation, not presence validation
    assert_match(/Parameter 'config' must be an object\/hash/, response_data["error"]["message"])
  end

  private

  def initialize_session
    request_id = "init-#{SecureRandom.hex(4)}"
    init_request = {
      jsonrpc: "2.0",
      id: request_id,
      method: "initialize",
      params: {
        protocolVersion: @protocol_version,
        clientInfo: {
          name: "Test Client",
          version: "1.0.0"
        },
        capabilities: {}
      }
    }

    post "/",
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream"
         },
         params: init_request.to_json

    assert_response :ok
    response.headers["Mcp-Session-Id"]
  end

  def send_initialized_notification(session_id)
    post "/",
         headers: {
           "CONTENT_TYPE" => "application/json",
           "Mcp-Session-Id" => session_id
         },
         params: {
           jsonrpc: "2.0",
           method: "notifications/initialized"
         }.to_json

    assert_response :ok
  end

  def setup_mcp_session
    @session_id = initialize_session
    send_initialized_notification(@session_id)
  end

  def mcp_headers
    {
      "Mcp-Session-Id" => @session_id,
      "CONTENT_TYPE" => "application/json"
    }
  end
end
