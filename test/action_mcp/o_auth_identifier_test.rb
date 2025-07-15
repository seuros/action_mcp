# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class OAuthIdentifierTest < ActionDispatch::IntegrationTest
    fixtures :users

    test "OAuthIdentifier declares correct authentication method" do
      assert_equal "oauth", ActionMCP::OAuthIdentifier.auth_method
    end

    test "OAuthIdentifier declares correct identifier name" do
      assert_equal :user, ActionMCP::OAuthIdentifier.identifier_name
    end

    test "resolve succeeds with valid OAuth info using user_id" do
      user = users(:oauth_test_user)
      oauth_info = { "user_id" => user.email }

      get "/gateway_up"
      # Simulate OAuth middleware setting the token info
      request.env["action_mcp.oauth_token_info"] = oauth_info
      identifier = ActionMCP::OAuthIdentifier.new(request)

      result = identifier.resolve
      assert_equal user, result
    end

    test "resolve succeeds with valid OAuth info using sub" do
      user = users(:oauth_test_user)
      oauth_info = { "sub" => user.email }

      get "/gateway_up"
      request.env["action_mcp.oauth_token_info"] = oauth_info
      identifier = ActionMCP::OAuthIdentifier.new(request)

      result = identifier.resolve
      assert_equal user, result
    end

    test "resolve succeeds with symbol keys in OAuth info" do
      user = users(:oauth_test_user)
      oauth_info = { user_id: user.email }

      get "/gateway_up"
      request.env["action_mcp.oauth_token_info"] = oauth_info
      identifier = ActionMCP::OAuthIdentifier.new(request)

      result = identifier.resolve
      assert_equal user, result
    end

    test "resolve creates new user when not found" do
      oauth_info = { "user_id" => "new-oauth-user@example.com" }

      get "/gateway_up"
      request.env["action_mcp.oauth_token_info"] = oauth_info
      identifier = ActionMCP::OAuthIdentifier.new(request)

      assert_difference "User.count", 1 do
        result = identifier.resolve
        assert_instance_of User, result
        assert_equal "new-oauth-user@example.com", result.email
      end
    end

    test "resolve creates user with @example.com suffix when uid has no domain" do
      oauth_info = { "user_id" => "testuser" }

      get "/gateway_up"
      request.env["action_mcp.oauth_token_info"] = oauth_info
      identifier = ActionMCP::OAuthIdentifier.new(request)

      result = identifier.resolve
      assert_instance_of User, result
      assert_equal "testuser@example.com", result.email
    end

    test "resolve finds existing user by modified email format" do
      existing_user = users(:oauth_test_user)
      oauth_info = { "user_id" => "oauth-test" } # Without @example.com

      get "/gateway_up"
      request.env["action_mcp.oauth_token_info"] = oauth_info
      identifier = ActionMCP::OAuthIdentifier.new(request)

      result = identifier.resolve
      assert_equal existing_user, result
    end

    test "resolve raises Unauthorized when OAuth info is missing" do
      get "/gateway_up"
      identifier = ActionMCP::OAuthIdentifier.new(request)

      error = assert_raises ActionMCP::GatewayIdentifier::Unauthorized do
        identifier.resolve
      end
      assert_equal "Missing OAuth info", error.message
    end

    test "resolve raises Unauthorized when OAuth info is nil" do
      get "/gateway_up"
      request.env["action_mcp.oauth_token_info"] = nil
      identifier = ActionMCP::OAuthIdentifier.new(request)

      error = assert_raises ActionMCP::GatewayIdentifier::Unauthorized do
        identifier.resolve
      end
      assert_equal "Missing OAuth info", error.message
    end

    test "resolve raises Unauthorized when OAuth info has no user identification" do
      oauth_info = { "scope" => "read", "exp" => Time.now.to_i + 3600 }

      get "/gateway_up"
      request.env["action_mcp.oauth_token_info"] = oauth_info
      identifier = ActionMCP::OAuthIdentifier.new(request)

      error = assert_raises ActionMCP::GatewayIdentifier::Unauthorized do
        identifier.resolve
      end
      assert_equal "Invalid OAuth info", error.message
    end
  end
end
