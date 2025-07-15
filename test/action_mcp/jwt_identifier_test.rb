# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class JwtIdentifierTest < ActionDispatch::IntegrationTest
    fixtures :users

    test "JwtIdentifier declares correct authentication method" do
      assert_equal "jwt", ActionMCP::JwtIdentifier.auth_method
    end

    test "JwtIdentifier declares correct identifier name" do
      assert_equal :user, ActionMCP::JwtIdentifier.identifier_name
    end

    test "resolve succeeds with valid JWT token using user_id" do
      user = users(:jwt_test_user)
      token = JWT.encode(
        { user_id: user.id },
        ActionMCP::JwtDecoder.secret,
        ActionMCP::JwtDecoder.algorithm
      )

      get "/gateway_up", headers: { "Authorization" => "Bearer #{token}" }
      identifier = ActionMCP::JwtIdentifier.new(request)

      result = identifier.resolve
      assert_equal user, result
    end

    test "resolve succeeds with valid JWT token using sub claim" do
      user = users(:jwt_test_user)
      token = JWT.encode(
        { sub: user.id },
        ActionMCP::JwtDecoder.secret,
        ActionMCP::JwtDecoder.algorithm
      )

      get "/gateway_up", headers: { "Authorization" => "Bearer #{token}" }
      identifier = ActionMCP::JwtIdentifier.new(request)

      result = identifier.resolve
      assert_equal user, result
    end

    test "resolve raises Unauthorized when Authorization header is missing" do
      get "/gateway_up"
      identifier = ActionMCP::JwtIdentifier.new(request)

      error = assert_raises ActionMCP::GatewayIdentifier::Unauthorized do
        identifier.resolve
      end
      assert_equal "Missing JWT", error.message
    end

    test "resolve raises Unauthorized when Authorization header is not Bearer format" do
      get "/gateway_up", headers: { "Authorization" => "Basic dXNlcjpwYXNz" }
      identifier = ActionMCP::JwtIdentifier.new(request)

      error = assert_raises ActionMCP::GatewayIdentifier::Unauthorized do
        identifier.resolve
      end
      assert_equal "Missing JWT", error.message
    end

    test "resolve raises Unauthorized with invalid JWT token" do
      get "/gateway_up", headers: { "Authorization" => "Bearer invalid.jwt.token" }
      identifier = ActionMCP::JwtIdentifier.new(request)

      error = assert_raises ActionMCP::GatewayIdentifier::Unauthorized do
        identifier.resolve
      end
      assert_match "Invalid JWT token:", error.message
    end

    test "resolve raises Unauthorized when user does not exist" do
      token = JWT.encode(
        { user_id: 99_999 },
        ActionMCP::JwtDecoder.secret,
        ActionMCP::JwtDecoder.algorithm
      )

      get "/gateway_up", headers: { "Authorization" => "Bearer #{token}" }
      identifier = ActionMCP::JwtIdentifier.new(request)

      error = assert_raises ActionMCP::GatewayIdentifier::Unauthorized do
        identifier.resolve
      end
      assert_equal "Invalid JWT user", error.message
    end

    test "resolve raises Unauthorized when token has no user identification" do
      token = JWT.encode(
        { exp: Time.now.to_i + 3600 },
        ActionMCP::JwtDecoder.secret,
        ActionMCP::JwtDecoder.algorithm
      )

      get "/gateway_up", headers: { "Authorization" => "Bearer #{token}" }
      identifier = ActionMCP::JwtIdentifier.new(request)

      error = assert_raises ActionMCP::GatewayIdentifier::Unauthorized do
        identifier.resolve
      end
      assert_equal "Invalid JWT user", error.message
    end
  end
end
