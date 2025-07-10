require "test_helper"
require "jwt"

class MCPJwtAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "jwt-test@example.com")
    @valid_token = JWT.encode(
      { user_id: @user.id },
      ActionMCP::JwtDecoder.secret,
      ActionMCP::JwtDecoder.algorithm
    )

    # Initialize a session first
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
    assert_not_nil @session_id
  end

  test "tools/list requires JWT authentication" do
    with_authentication_config([ "jwt" ]) do
      # Try without token - should fail
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

      assert_response :unauthorized
      body = JSON.parse(response.body)
      assert_match "Missing token", response.parsed_body["error"]["message"]
    end
  end

  test "tools/list works with valid JWT" do
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
        "Authorization" => "Bearer #{@valid_token}"
      }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["result"]["tools"].is_a?(Array)
  end

  test "tools/call with user_info shows authenticated user" do
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
        "Authorization" => "Bearer #{@valid_token}"
      }

    assert_response :success
    body = JSON.parse(response.body)

    # Check the tool response
    content = body["result"]["content"]
    assert content.is_a?(Array)
    assert content.any? { |c| c["text"]&.include?(@user.email) }
    assert content.any? { |c| c["text"]&.include?(@user.id.to_s) }
  end

  test "invalid JWT token returns unauthorized" do
    with_authentication_config([ "jwt" ]) do
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

      assert_response :unauthorized
      body = JSON.parse(response.body)
      assert_equal "Invalid token", body["error"]["message"]
    end
  end

  test "JWT with non-existent user returns unauthorized" do
    with_authentication_config([ "jwt" ]) do
      token = JWT.encode(
        { user_id: 99999 },
        ActionMCP::JwtDecoder.secret,
        ActionMCP::JwtDecoder.algorithm
      )

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
          "Authorization" => "Bearer #{token}"
        }

      assert_response :unauthorized
      body = JSON.parse(response.body)
      assert_equal "Unauthorized", body["error"]["message"]
    end
  end

  test "initialize request does not require authentication" do
    # Create a new session without any auth token
    post "/",
      params: {
        jsonrpc: "2.0",
        id: 100,
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
    body = JSON.parse(response.body)
    assert body["result"]["protocolVersion"]
    assert body["result"]["capabilities"]
  end
end
