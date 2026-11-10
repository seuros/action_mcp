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
    mcp_post("tools/list", session_id: @session_id)

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
    mcp_post("tools/call", {
      name: "numeric_array",
      arguments: {
        numbers: [ 1, 2.5, 3, 4.75, 5 ]
      }
    }, id: 2, session_id: @session_id)

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert response_data["result"]
    assert_equal "16.25", response_data["result"]["content"].first["text"]
  end

  test "rejects string numbers before tool coercion" do
    setup_mcp_session

    mcp_post("tools/call", {
      name: "numeric_array",
      arguments: {
        numbers: [ "1", "2.5", "3.14" ]
      }
    }, session_id: @session_id)

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal true, response_data["result"]["isError"]
    assert_match(/is not a number/, response_data["result"]["content"].first["text"])
  end

  test "rejects a missing required numbers argument" do
    setup_mcp_session

    mcp_post("tools/call", {
      name: "numeric_array",
      arguments: {}
    }, session_id: @session_id)

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal true, response_data["result"]["isError"]
    assert_match(/missing required properties: numbers/, response_data["result"]["content"].first["text"])
  end

  private

  def setup_mcp_session
    @session_id = initialize_mcp_session(protocol_version: @protocol_version, client_name: "Test Client",
                                         client_version: "1.0.0")
    assert_response :accepted
  end

  test "rejects mixed valid and invalid values" do
    setup_mcp_session

    mcp_post("tools/call", {
      name: "numeric_array",
      arguments: {
        numbers: [ 1, "2", "invalid", 3.5, nil, "4.5", {}, [] ]
      }
    }, session_id: @session_id)

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal true, response_data["result"]["isError"]
    assert_match(%r{value at `/numbers/1` is not a number}, response_data["result"]["content"].first["text"])
  end

  test "works with empty array" do
    setup_mcp_session

    mcp_post("tools/call", {
      name: "numeric_array",
      arguments: {
        numbers: []
      }
    }, session_id: @session_id)

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal "0", response_data["result"]["content"].first["text"]
  end

  test "handles very large numbers" do
    setup_mcp_session

    mcp_post("tools/call", {
      name: "numeric_array",
      arguments: {
        numbers: [ 1e10, 2e10, 3e10 ]
      }
    }, session_id: @session_id)

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal "60000000000.0", response_data["result"]["content"].first["text"]
  end

  test "handles negative numbers" do
    setup_mcp_session

    mcp_post("tools/call", {
      name: "numeric_array",
      arguments: {
        numbers: [ -5, -2.5, 0, 2.5, 5 ]
      }
    }, session_id: @session_id)

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]
    assert_equal "0.0", response_data["result"]["content"].first["text"]
  end
end
