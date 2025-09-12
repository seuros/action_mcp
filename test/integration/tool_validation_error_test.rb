# frozen_string_literal: true

require "test_helper"
require "action_mcp/test_helper"

class ToolValidationErrorTest < ActionDispatch::IntegrationTest
  include ActionMCP::TestHelper

  setup do
    @headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "Mcp-Protocol-Version" => ActionMCP::LATEST_VERSION
    }

    @current_request_id = 1  # Reset request ID for each test

    # Initialize the MCP session
    initialize_mcp_session
  end

  test "tool exceptions are returned as MCP-compliant errors" do
    response_json = call_environment_tool("staging")

    # According to MCP spec, tool errors should return a successful response
    # with isError: true in the result
    assert response_json["result"], "Expected result field in response, got: #{response_json.inspect}"
    assert response_json["result"]["isError"] == true, "Expected isError: true for validation error"
    assert response_json["result"]["content"], "Expected content field with error message"

    # The error message should be in the content
    error_content = response_json["result"]["content"]
    assert error_content.is_a?(Array), "Content should be an array"
    assert error_content.any? { |c| c["type"] == "text" }, "Should have text content"

    error_text = error_content.find { |c| c["type"] == "text" }["text"]
    assert error_text == "Validation failed: 'staging' is not supported", "Error must be indicative of validation failure, got: '#{error_text.inspect}'"
  end

  test "tool succeeds when validation passes" do
    response_json = call_environment_tool("production")

    assert response_json["result"], "Expected result field, got: #{response_json.inspect}"
    assert_not response_json["result"]["isError"], "Should not be an error"
    assert response_json["result"]["content"], "Expected content field"

    content = response_json["result"]["content"]
    assert content.any? { |c| c["text"]&.include?("Successfully set environment to: production") }
  end

  private

  def initialize_mcp_session
    init_params = {
      jsonrpc: "2.0",
      id: 0,
      method: "initialize",
      params: {
        protocolVersion: ActionMCP::LATEST_VERSION,
        capabilities: {},
        clientInfo: { name: "test", version: "1.0" }
      }
    }

    post action_mcp_path, params: init_params.to_json, headers: @headers
    assert_response :success

    session_id = response.headers["Mcp-Session-Id"]
    assert session_id, "Expected Mcp-Session-Id in response headers"

    @headers["Mcp-Session-Id"] = session_id

    post action_mcp_path,
         params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json,
         headers: @headers
  end

  def call_environment_tool(env_value)
    @current_request_id ||= 1
    call_params = {
      jsonrpc: "2.0",
      id: @current_request_id,
      method: "tools/call",
      params: {
        name: "environment",
        arguments: {
          env: env_value
        }
      }
    }
    @current_request_id += 1

    post action_mcp_path, params: call_params.to_json, headers: @headers
    assert_response :success

    JSON.parse(response.body)
  end
end
