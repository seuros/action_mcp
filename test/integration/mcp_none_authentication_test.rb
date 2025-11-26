# frozen_string_literal: true

require "test_helper"

class MCPNoneAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    # Initialize a session
    post "/",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "initialize",
           params: {
             protocolVersion: "2025-06-18",
             clientInfo: { name: "test-client", version: "1.0" },
             capabilities: {}
           }
         }.to_json,
         headers: {
           "Content-Type" => "application/json",
           "Accept" => "application/json"
         }

    assert_response :success
    @session_id = response.headers["Mcp-Session-Id"]
  end

  test "tools/list works without authentication in none mode" do
    with_authentication_config([ "none" ]) do
      post "/",
           params: {
             jsonrpc: "2.0",
             id: 2,
             method: "tools/list"
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      body = response.parsed_body
      assert body["result"]["tools"].is_a?(Array)
    end
  end

  test "user_info tool shows default dev user in none mode" do
    with_authentication_config([ "none" ]) do
      post "/",
           params: {
             jsonrpc: "2.0",
             id: 3,
             method: "tools/call",
             params: {
               name: "user_info",
               arguments: { include_sensitive: false, include_auth_details: false }
             }
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      body = response.parsed_body

      # Check the tool response
      assert body["result"], "Response should have result: #{body.inspect}"
      content = body["result"]["content"]
      assert content.is_a?(Array), "Content should be an array: #{content.inspect}"
      # Should have the default dev user
      assert(content.any? { |c| c["text"]&.include?("dev@localhost") }, "Should contain dev user info")
    end
  end

  test "fallback authentication allows requests without authentication" do
    with_authentication_config(%w[api_key none]) do
      # Try without authentication - should succeed with fallback to none
      post "/",
           params: {
             jsonrpc: "2.0",
             id: 2,
             method: "tools/list"
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id
           }

      assert_response :success
      body = response.parsed_body
      assert body["result"]["tools"].is_a?(Array)
    end
  end
end
