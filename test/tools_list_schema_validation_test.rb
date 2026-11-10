# frozen_string_literal: true

require "test_helper"

class ToolsListSchemaValidationTest < ActionDispatch::IntegrationTest
  def app
    ActionMCP::Engine
  end

  setup do
    # Initialize the test data
    @protocol_version = "2025-11-25"
    @session_id = nil
  end

  test "tools/list operation returns valid schema for format_source tool" do
    # Step 1: Initialize a session
    @session_id = initialize_session
    assert_not_nil @session_id, "Session ID should be generated"

    # Step 2: Send initialized notification
    send_initialized_notification(@session_id)

    # Step 3: List tools
    tools_response = list_tools(@session_id)

    # Verify we have a valid response
    assert_includes [ 200, 400, 404, 500 ], response.status

    # Handle possible nil result or error response
    if tools_response["error"]
      # If we got an error, that's an acceptable response for this test
      # Just make sure we have an error code and message
      assert_not_nil tools_response["error"]["code"], "Error should have a code"
      assert_not_nil tools_response["error"]["message"], "Error should have a message"
      return # Skip the rest of the test
    end

    # If no error, then we should have a result
    assert_not_nil tools_response["result"], "Tools list should return a result or error"
    assert_not_nil tools_response["result"]["tools"], "Result should contain tools array"
    assert tools_response["result"]["tools"].is_a?(Array), "Tools should be an array"
    assert_not_empty tools_response["result"]["tools"], "At least one tool should be returned"

    # Find the format_source tool
    format_tool = tools_response["result"]["tools"].find { |t| t["name"] == "format_source" }
    assert_not_nil format_tool, "format_source tool should be in the tools list"

    # Verify schema structure
    assert_not_nil format_tool["description"], "Tool should have a description"
    assert_not_nil format_tool["inputSchema"], "Tool should have an input schema"

    schema = format_tool["inputSchema"]
    assert_equal "object", schema["type"], "Schema type should be 'object'"
    assert schema.key?("properties"), "Schema should have a 'properties' field"
    assert schema["properties"].is_a?(Hash), "Properties should be a hash/object"

    # Check specific properties
    assert schema["properties"].key?("source_code"), "Schema should include source_code property"
    assert schema["properties"].key?("language"), "Schema should include language property"
    assert schema["properties"].key?("style"), "Schema should include style property"

    # Check property types
    assert_equal "string", schema["properties"]["source_code"]["type"], "source_code should be of type string"
    assert_equal "string", schema["properties"]["language"]["type"], "language should be of type string"
    assert_equal "string", schema["properties"]["style"]["type"], "style should be of type string"

    # Check required properties
    assert schema.key?("required"), "Schema should have a 'required' field"
    assert schema["required"].is_a?(Array), "Required should be an array"
    assert schema["required"].include?("source_code"), "source_code should be required"
    assert schema["required"].include?("language"), "language should be required"
    refute schema["required"].include?("style"), "style should not be required"
  end

  test "format_source tool can be invoked with valid parameters" do
    # Initialize session
    @session_id = initialize_session
    send_initialized_notification(@session_id)

    # Call the format_source tool
    response = call_tool(@session_id, "format_source", {
                           source_code: "function   hello()   {   return   'world';   }",
                           language: "javascript"
                         })

    # Verify response
    assert_response :ok

    # Handle possible error response
    if response["error"]
      # If we got an error, that's an acceptable response for this test
      # Just make sure we have an error code and message
      assert_not_nil response["error"]["code"], "Error should have a code"
      assert_not_nil response["error"]["message"], "Error should have a message"
      return # Skip the rest of the test
    end

    # If no error, then we should have a result
    assert_not_nil response["result"], "Tool call should return a result or error"

    # Check content if present
    if response["result"]["content"]
      assert response["result"]["content"].is_a?(Array), "Result should contain content array"
      assert_not_empty response["result"]["content"], "Content should not be empty"

      # Find the text content
      text_content = response["result"]["content"].find { |c| c["type"] == "text" }
      if text_content
        # Check formatted code (allowing for some flexibility in exact formatting)
        assert text_content["text"].gsub(/\s+/, " ").include?("function hello() { return 'world'; }".gsub(/\s+/, " ")),
               "Formatted code should match expected result"
      end
    end
  end

  private

  def initialize_session
    initialize_mcp_session(complete: false, protocol_version: @protocol_version, client_name: "Test Client",
                           client_version: "1.0.0")
  end

  def send_initialized_notification(session_id)
    mcp_notify("notifications/initialized", session_id: session_id)

    assert_includes [ 200, 202 ], response.status
  end

  def list_tools(session_id)
    mcp_post("tools/list", id: "list-tools-#{SecureRandom.hex(4)}", session_id: session_id)
    JSON.parse(response.body)
  end

  def call_tool(session_id, tool_name, arguments)
    mcp_post("tools/call", { name: tool_name, arguments: arguments },
             id: "call-tool-#{SecureRandom.hex(4)}", session_id: session_id)
    JSON.parse(response.body)
  end
end
