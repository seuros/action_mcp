# frozen_string_literal: true

require "test_helper"

class GatewayIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "accepts valid JWT and sets current user" do
    token = JWT.encode({ user_id: @user.id }, ActionMCP::JwtDecoder.secret, ActionMCP::JwtDecoder.algorithm)

    get "/gateway_up", headers: {
      "Authorization" => "Bearer #{token}"
    }

    assert_response :success
    body = response.parsed_body
    assert_equal @user.id, body["user_id"]
    assert_equal @user.email, body["user_email"]
  end

  test "rejects missing token" do
    with_authentication_config([ "jwt" ]) do
      get "/gateway_up"
      assert_response :unauthorized
      assert_match "Missing JWT", response.parsed_body["error"]
    end
  end

  test "rejects invalid token" do
    with_authentication_config([ "jwt" ]) do
      get "/gateway_up", headers: { "Authorization" => "Bearer not.a.jwt" }
      assert_response :unauthorized
      assert_match "Invalid JWT token", response.parsed_body["error"]
    end
  end

  test "rejects token with non-existent user" do
    with_authentication_config([ "jwt" ]) do
      token = JWT.encode({ user_id: 999 }, ActionMCP::JwtDecoder.secret, ActionMCP::JwtDecoder.algorithm)

      get "/gateway_up", headers: { "Authorization" => "Bearer #{token}" }
      assert_response :unauthorized
      assert_match "Invalid JWT user", response.parsed_body["error"]
    end
  end
end
