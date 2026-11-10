# frozen_string_literal: true

require "test_helper"
require "action_mcp/test_helper"

class ToolValidationErrorTest < ActionDispatch::IntegrationTest
  include ActionMCP::TestHelper

  setup do
    @session_id = initialize_mcp_session(path: action_mcp_path)
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

  test "undeclared param on a strict tool returns a tool execution error naming the key" do
    response_json = call_tool("add", { x: 5, y: 3, root_id: "oops" })

    assert response_json["result"], "Expected tool result, got: #{response_json.inspect}"
    assert_equal true, response_json["result"]["isError"]
    error_text = response_json["result"]["content"].find { |content| content["type"] == "text" }["text"]
    assert_includes error_text, "root_id",
                    "Error message should name the offending key"
  end

  test "unknown tool returns invalid params" do
    response_json = call_tool("missing-tool", {})
    assert_equal(-32_602, response_json.dig("error", "code"))
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

  def call_environment_tool(env_value)
    call_tool("environment", { env: env_value })
  end

  def call_tool(name, arguments)
    @request_id = (@request_id || 0) + 1
    mcp_post("tools/call", { name: name, arguments: arguments },
             id: @request_id, path: action_mcp_path, session_id: @session_id,
             protocol_version: ActionMCP::LATEST_VERSION)
    assert_response :success
    JSON.parse(response.body)
  end
end
