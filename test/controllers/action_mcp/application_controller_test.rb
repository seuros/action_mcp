# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ApplicationControllerTestBase < ActionDispatch::IntegrationTest
    include SessionFixtureHelper
    fixtures :action_mcp_sessions

    attr_reader :original_preference

    teardown do
      ActionMCP.configuration.post_response_preference = original_preference
    end

    def app
      ActionMCP::Engine
    end

    # Helper to create a session for tests
    def create_initialized_session
      # Get fixture data
      fixture_session = action_mcp_sessions(:step1_session)

      # Create session in the session store using the helper
      Server.session_store.create_session(
        fixture_session.id,
        session_payload_from_fixture(fixture_session)
      )
    end
  end

  class ApplicationControllerJSONTest < ApplicationControllerTestBase
    setup do
      @original_preference = ActionMCP.configuration.post_response_preference

      ActionMCP.configuration.post_response_preference = :json
    end

    test "JSON response works correctly" do
      session = create_initialized_session
      session_id = session.id

      request_payload = {
        jsonrpc: "2.0",
        id: "test-json-1",
        method: "tools/list"
      }

      post "/",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "ACCEPT" => "application/json, text/event-stream",
             "Mcp-Session-Id" => session_id
           },
           params: request_payload.to_json

      assert_response :success
      assert_match %r{application/json}, response.headers["Content-Type"]
      assert_not_nil response.parsed_body["result"]
    end

    test "complete basic MCP workflow - initialize, list tools, call tool" do
      # ====================================================================
      # STEP 1: Initialize the session
      # ====================================================================

      init_request = {
        jsonrpc: "2.0",
        id: "init-1",
        method: "initialize",
        params: {
          protocolVersion: "2025-06-18",
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
             "ACCEPT" => "application/json"
           },
           params: init_request.to_json

      assert_response :success

      # Parse the initialization response
      init_response = response.parsed_body
      assert_equal "2.0", init_response["jsonrpc"]

      # Init response: #{init_response.inspect}
      assert_equal "init-1", init_response["id"], "ID should be preserved in response"
      assert_not_nil init_response["result"], "Should have a result if no error"

      # Extract session ID from header
      session_id = response.headers["Mcp-Session-Id"]
      assert_not_nil session_id, "Session ID should be present in Mcp-Session-Id header"

      # Only verify capabilities if we got a success result
      capabilities = init_response["result"]["capabilities"]
      assert_not_nil capabilities["tools"], "Server should expose tools capability"
      assert_not_nil capabilities["prompts"], "Server should expose prompts capability"
      assert_not_nil capabilities["resources"]

      # Verify protocol version matches
      assert_equal "2025-06-18", init_response["result"]["protocolVersion"]

      # ====================================================================
      # STEP 2: Send initialized notification (required by protocol)
      # ====================================================================

      initialized_notification = {
        jsonrpc: "2.0",
        method: "notifications/initialized"
      }

      post "/",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "ACCEPT" => "application/json",
             "Mcp-Session-Id" => session_id
           },
           params: initialized_notification.to_json

      # The server might return 202 Accepted for notifications
      assert_response :accepted

      # ====================================================================
      # STEP 3: List available tools
      # ====================================================================

      list_tools_request = {
        jsonrpc: "2.0",
        id: "list-tools-1",
        method: "tools/list"
      }

      post "/",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "ACCEPT" => "application/json",
             "Mcp-Session-Id" => session_id
           },
           params: list_tools_request.to_json

      assert_response :ok

      # Parse the tools list response
      tools_response = response.parsed_body
      assert_equal "2.0", tools_response["jsonrpc"]
      assert_equal "list-tools-1", tools_response["id"], "ID should be preserved in response"
      assert_not_nil tools_response["result"]

      # Verify tools are returned if result is present
      tools = tools_response["result"]["tools"]
      assert_instance_of Array, tools
      assert_not_empty tools, "Server should have at least one tool"

      # Find a specific tool (calculate_sum)
      calculate_sum_tool = tools.find { |tool| tool["name"] == "calculate_sum" }
      assert_not_nil calculate_sum_tool, "calculate_sum tool should be available"

      # Verify tool structure
      assert_equal "calculate_sum", calculate_sum_tool["name"]

      # These checks only run if we found the calculate_sum_tool
      assert_not_nil calculate_sum_tool["description"]
      assert_not_nil calculate_sum_tool["inputSchema"]
      assert_equal "object", calculate_sum_tool["inputSchema"]["type"]
      assert_not_nil calculate_sum_tool["inputSchema"]["properties"]
      assert_includes calculate_sum_tool["inputSchema"]["required"], "a"
      assert_includes calculate_sum_tool["inputSchema"]["required"], "b"

      # ====================================================================
      # STEP 4: Call the calculate_sum tool
      # ====================================================================

      call_tool_request = {
        jsonrpc: "2.0",
        id: "call-tool-1",
        method: "tools/call",
        params: {
          name: "calculate_sum",
          arguments: {
            a: 15,
            b: 25
          }
        }
      }

      post "/",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "ACCEPT" => "application/json",
             "Mcp-Session-Id" => session_id
           },
           params: call_tool_request.to_json

      assert_response :ok

      # Parse the tool call response
      call_response = response.parsed_body
      assert_equal "2.0", call_response["jsonrpc"]
      assert_equal "call-tool-1", call_response["id"], "ID should be preserved in response"

      assert_not_nil call_response["result"]

      # Verify tool execution result if we have content
      content = call_response["result"]["content"]
      assert_instance_of Array, content
      assert_not_empty content

      # The calculate_sum tool should return the sum as text
      text_content = content.find { |item| item["type"] == "text" }
      assert_not_nil text_content, "Tool should return text content"
      assert_equal "40.0", text_content["text"], "15 + 25 should equal 40"

      # ====================================================================
      # STEP 5: List available prompts (optional verification)
      # ====================================================================

      list_prompts_request = {
        jsonrpc: "2.0",
        id: "list-prompts-1",
        method: "prompts/list"
      }

      post "/",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "ACCEPT" => "application/json",
             "Mcp-Session-Id" => session_id
           },
           params: list_prompts_request.to_json

      assert_response :ok

      prompts_response = response.parsed_body
      assert_not_nil prompts_response["result"]["prompts"] if prompts_response["result"]
      # ====================================================================
      # STEP 6: Verify session state
      # ====================================================================

      # Retrieve the session from session store
      session = Server.session_store.load_session(session_id)
      assert_not_nil session
      assert_equal "initialized", session.status
      assert_equal "2025-06-18", session.protocol_version
      assert session.initialized?

      # Skip message history verification for volatile session store
      # The volatile store doesn't create structured message objects
      if session.respond_to?(:messages) && session.messages.first.respond_to?(:jsonrpc_id)
        # Verify message history
        messages = session.messages.order(:created_at)

        # Should have the init request + init response
        init_request_msg = messages.find { |m| m.jsonrpc_id == "init-1" && m.message_type == "request" }
        init_response_msg = messages.find { |m| m.jsonrpc_id == "init-1" && m.message_type == "response" }
        assert_not_nil init_request_msg
        assert_not_nil init_response_msg

        # Should have the tools/list request + response
        tools_request_msg = messages.find { |m| m.jsonrpc_id == "list-tools-1" && m.message_type == "request" }
        tools_response_msg = messages.find { |m| m.jsonrpc_id == "list-tools-1" && m.message_type == "response" }
        assert_not_nil tools_request_msg
        assert_not_nil tools_response_msg

        # Should have the tools/call request + response
        call_request_msg = messages.find { |m| m.jsonrpc_id == "call-tool-1" && m.message_type == "request" }
        call_response_msg = messages.find { |m| m.jsonrpc_id == "call-tool-1" && m.message_type == "response" }
        assert_not_nil call_request_msg
        assert_not_nil call_response_msg
      end

      # ====================================================================
      # STEP 7: Cleanup - terminate the session
      # ====================================================================

      delete "/", headers: { "Mcp-Session-Id" => session_id }
      assert_response :no_content

      # Verify session is closed
      session.reload
      assert_equal "closed", session.status
      assert_not_nil session.ended_at
    end

    test "error handling in basic workflow" do
      # Test initialization with wrong protocol version
      init_request = {
        jsonrpc: "2.0",
        id: "bad-init",
        method: "initialize",
        params: {
          protocolVersion: "1.0.0", # Wrong version
          clientInfo: { name: "Test", version: "1.0" },
          capabilities: {}
        }
      }

      post "/",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "ACCEPT" => "application/json"
           },
           params: init_request.to_json

      assert_response :ok
      error_response = response.parsed_body
      assert_not_nil error_response["error"]
      assert_equal(-32_602, error_response["error"]["code"])
      assert_match(/Unsupported protocol version/, error_response["error"]["message"])
      # The ID should match the request ID if present
      assert_equal "bad-init", error_response["id"]
    end

    test "ping" do
      session = create_initialized_session
      session_id = session.id

      request_payload = {
        jsonrpc: "2.0",
        id: "ping-1",
        method: "ping"
      }

      post "/",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "ACCEPT" => "application/json, text/event-stream",
             "Mcp-Session-Id" => session_id
           },
           params: request_payload.to_json

      assert_response :success
      assert_match %r{application/json}, response.headers["Content-Type"]
      assert_equal "ping-1", response.parsed_body["id"]
    end
  end
end
