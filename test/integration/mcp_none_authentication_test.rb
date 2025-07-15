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
             protocolVersion: "2025-03-26",
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
               arguments: { include_email: true }
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
      content = body["result"]["content"]
      assert content.is_a?(Array)
      # Should have the default dev user
      assert(content.any? { |c| c["text"]&.include?("dev@localhost") })
    end
  end

  test "fallback authentication allows requests without JWT" do
    with_authentication_config(%w[jwt none]) do
      # Try without token - should succeed with fallback to none
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

  test "fallback authentication still accepts valid JWT" do
    with_authentication_config(%w[jwt none]) do
      user = User.create!(email: "fallback-test@example.com")
      valid_token = JWT.encode(
        { user_id: user.id },
        ActionMCP::JwtDecoder.secret,
        ActionMCP::JwtDecoder.algorithm
      )

      post "/",
           params: {
             jsonrpc: "2.0",
             id: 3,
             method: "tools/call",
             params: {
               name: "user_info",
               arguments: { include_email: true }
             }
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id,
             "Authorization" => "Bearer #{valid_token}"
           }

      assert_response :success
      body = response.parsed_body

      # Should see the JWT authenticated user
      content = body["result"]["content"]
      assert content.is_a?(Array)
      assert(content.any? { |c| c["text"]&.include?(user.email) })
    end
  end

  test "invalid JWT falls back to none authentication instead of failing" do
    with_authentication_config(%w[jwt none]) do
      post "/",
           params: {
             jsonrpc: "2.0",
             id: 2,
             method: "tools/list"
           }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "Mcp-Session-Id" => @session_id,
             "Authorization" => "Bearer invalid.jwt.token"
           }

      # Should succeed with fallback to none instead of failing
      assert_response :success
      body = response.parsed_body
      assert body["result"]["tools"].is_a?(Array)
    end
  end
end
