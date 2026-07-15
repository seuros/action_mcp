# frozen_string_literal: true

require "test_helper"

class NumericArrayIntegrationTest < ActionDispatch::IntegrationTest
  include ActionMCP::TestHelper

  setup do
    @protocol_version = "2025-11-25"
    @session_id = nil
  end

  test "numeric array tool works through full MCP request flow" do
    setup_mcp_session

    # First, list tools to ensure it's available
    post "/",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/list"
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    tool_names = response_data["result"]["tools"].map { |t| t["name"] }
    assert_includes tool_names, "numeric_array"

    # Find the numeric array tool
    numeric_tool = response_data["result"]["tools"].find { |t| t["name"] == "numeric_array" }
    assert_not_nil numeric_tool

    # Verify schema
    schema = numeric_tool["inputSchema"]
    assert_equal "object", schema["type"]
    assert schema["properties"]["numbers"]
    assert_equal "array", schema["properties"]["numbers"]["type"]
    assert_equal "number", schema["properties"]["numbers"]["items"]["type"]

    # Call the tool with various inputs
    post "/",
         params: {
           jsonrpc: "2.0",
           id: 2,
           method: "tools/call",
           params: {
             name: "numeric_array",
             arguments: {
               numbers: [ 1, 2.5, 3, 4.75, 5 ]
             }
           }
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert response_data["result"]
    assert_equal "16.25", response_data["result"]["content"].first["text"]
  end

  test "rejects string numbers before tool coercion" do
    setup_mcp_session

    post "/",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "numeric_array",
             arguments: {
               numbers: [ "1", "2.5", "3.14" ]
             }
           }
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal true, response_data["result"]["isError"]
    assert_match(/is not a number/, response_data["result"]["content"].first["text"])
  end

  test "rejects a missing required numbers argument" do
    setup_mcp_session

    post "/",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "numeric_array",
             arguments: {}
           }
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal true, response_data["result"]["isError"]
    assert_match(/missing required properties: numbers/, response_data["result"]["content"].first["text"])
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
           "ACCEPT" => "application/json, text/event-stream",
           "Mcp-Session-Id" => session_id
         },
         params: {
           jsonrpc: "2.0",
           method: "notifications/initialized"
         }.to_json

    assert_response :accepted
  end

  def setup_mcp_session
    @session_id = initialize_session
    send_initialized_notification(@session_id)
  end

  def mcp_headers
    {
      "Mcp-Session-Id" => @session_id,
      "CONTENT_TYPE" => "application/json",
      "ACCEPT" => "application/json, text/event-stream"
    }
  end

  test "rejects mixed valid and invalid values" do
    setup_mcp_session

    post "/",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "numeric_array",
             arguments: {
               numbers: [ 1, "2", "invalid", 3.5, nil, "4.5", {}, [] ]
             }
           }
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal true, response_data["result"]["isError"]
    assert_match(%r{value at `/numbers/1` is not a number}, response_data["result"]["content"].first["text"])
  end

  test "works with empty array" do
    setup_mcp_session

    post "/",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "numeric_array",
             arguments: {
               numbers: []
             }
           }
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal "0", response_data["result"]["content"].first["text"]
  end

  test "handles very large numbers" do
    setup_mcp_session

    post "/",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "numeric_array",
             arguments: {
               numbers: [ 1e10, 2e10, 3e10 ]
             }
           }
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal "60000000000.0", response_data["result"]["content"].first["text"]
  end

  test "handles negative numbers" do
    setup_mcp_session

    post "/",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "numeric_array",
             arguments: {
               numbers: [ -5, -2.5, 0, 2.5, 5 ]
             }
           }
         },
         headers: mcp_headers,
         as: :json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal "0.0", response_data["result"]["content"].first["text"]
  end
end
