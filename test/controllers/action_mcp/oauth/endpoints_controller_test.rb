# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module OAuth
    class EndpointsControllerTest < ActionDispatch::IntegrationTest
      include Engine.routes.url_helpers

      setup do
        @original_auth_methods = ActionMCP.configuration.authentication_methods
        @original_oauth_config = ActionMCP.configuration.oauth_config

        ActionMCP.configuration.authentication_methods = [ "oauth" ]
        ActionMCP.configuration.oauth_config = {
          "pkce_required" => false,
          "enable_refresh_tokens" => true,
          "enable_client_credentials" => true,
          "auto_approve_clients" => [ "test_client" ],
          "scopes_supported" => [ "mcp:tools", "mcp:resources" ]
        }

        # Clear OAuth storage
        ActionMCP::OAuth::Provider.send(:storage).clear_all

        # Clear cached config
        ActionMCP::OAuth::Provider.instance_variable_set(:@oauth_config, nil)

        # Register a default client for testing
        ActionMCP::OAuth::Provider.register_client(
          client_id: "test_client",
          client_secret: "test_secret", # Add a secret for client_credentials_grant
          redirect_uris: [ "https://example.com/callback" ],
          grant_types: [ "authorization_code", "refresh_token", "client_credentials" ],
          response_types: [ "code" ],
          token_endpoint_auth_method: "client_secret_basic"
        )
      end

      teardown do
        ActionMCP.configuration.authentication_methods = @original_auth_methods
        ActionMCP.configuration.oauth_config = @original_oauth_config
      end

      test "authorize endpoint returns 404 when OAuth not enabled" do
        ActionMCP.configuration.authentication_methods = [ "jwt" ]

        get oauth_authorize_path, params: {
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          response_type: "code"
        }

        assert_response :not_found
      end

      test "authorize endpoint requires required parameters" do
        get oauth_authorize_path, params: { client_id: "test_client" }
        assert_response :bad_request

        response_body = JSON.parse(response.body)
        assert_equal "invalid_request", response_body["error"]
      end

      test "authorize endpoint only supports code response type" do
        get oauth_authorize_path, params: {
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          response_type: "token"
        }

        assert_response :bad_request
        response_body = JSON.parse(response.body)
        assert_equal "unsupported_response_type", response_body["error"]
      end

      test "authorize endpoint redirects with authorization code for auto-approved client" do
        get oauth_authorize_path, params: {
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          response_type: "code",
          scope: "mcp:tools",
          state: "random_state"
        }

        assert_response :redirect

        redirect_url = URI.parse(response.location)
        query_params = CGI.parse(redirect_url.query)

        assert_equal "https", redirect_url.scheme
        assert_equal "example.com", redirect_url.host
        assert_equal "/callback", redirect_url.path
        assert query_params["code"].first.present?
        assert_equal "random_state", query_params["state"].first
      end

      test "token endpoint handles authorization_code grant" do
        # First get an authorization code
        get oauth_authorize_path, params: {
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          response_type: "code",
          scope: "mcp:tools"
        }

        redirect_url = URI.parse(response.location)
        query_params = CGI.parse(redirect_url.query)
        code = query_params["code"].first

        # Exchange code for token
        post oauth_token_path, params: {
          grant_type: "authorization_code",
          code: code,
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          client_secret: "test_secret"
        }

        assert_response :success

        token_response = JSON.parse(response.body)
        assert_equal "Bearer", token_response["token_type"]
        assert_equal 3600, token_response["expires_in"]
        assert_equal "mcp:tools", token_response["scope"]
        assert token_response["access_token"].present?
        assert token_response["refresh_token"].present?
      end

      test "token endpoint handles refresh_token grant" do
        # Get initial tokens
        code = get_authorization_code

        post oauth_token_path, params: {
          grant_type: "authorization_code",
          code: code,
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          client_secret: "test_secret"
        }

        initial_response = JSON.parse(response.body)
        refresh_token = initial_response["refresh_token"]

        # Use refresh token
        post oauth_token_path, params: {
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: "test_client",
          client_secret: "test_secret"
        }

        assert_response :success

        refresh_response = JSON.parse(response.body)
        assert_equal "Bearer", refresh_response["token_type"]
        assert refresh_response["access_token"].present?
        assert_not_equal initial_response["access_token"], refresh_response["access_token"]
      end

      test "token endpoint handles client_credentials grant" do
        auth_header = "Basic " + Base64.encode64("test_client:test_secret").strip

        post oauth_token_path,
          params: {
            grant_type: "client_credentials",
            scope: "mcp:tools"
          },
          headers: {
            "Authorization" => auth_header
          }

        assert_response :success

        token_response = JSON.parse(response.body)
        assert_equal "Bearer", token_response["token_type"]
        assert_equal "mcp:tools", token_response["scope"]
        assert token_response["access_token"].present?
        assert_nil token_response["refresh_token"] # No refresh token for client credentials
      end

      test "token endpoint rejects unsupported grant types" do
        post oauth_token_path, params: {
          grant_type: "password",
          username: "user",
          password: "pass"
        }

        assert_response :bad_request

        error_response = JSON.parse(response.body)
        assert_equal "unsupported_grant_type", error_response["error"]
      end

      test "introspect endpoint validates active token" do
        access_token = get_access_token

        auth_header = "Basic " + Base64.encode64("test_client:test_secret").strip

        post oauth_introspect_path,
          params: { token: access_token },
          headers: { "Authorization" => auth_header }

        assert_response :success

        introspection = JSON.parse(response.body)
        assert introspection["active"]
        assert_equal "test_client", introspection["client_id"]
        assert_equal "mcp:tools", introspection["scope"]
        assert_equal "Bearer", introspection["token_type"]
      end

      test "introspect endpoint returns inactive for invalid token" do
        auth_header = "Basic " + Base64.encode64("test_client:test_secret").strip

        post oauth_introspect_path,
          params: { token: "invalid_token" },
          headers: { "Authorization" => auth_header }

        assert_response :success

        introspection = JSON.parse(response.body)
        assert_equal false, introspection["active"]
      end

      test "revoke endpoint revokes access token" do
        access_token = get_access_token

        # Verify token is active
        auth_header = "Basic " + Base64.encode64("test_client:test_secret").strip
        post oauth_introspect_path,
          params: { token: access_token },
          headers: { "Authorization" => auth_header }

        introspection = JSON.parse(response.body)
        assert introspection["active"]

        # Revoke token
        post oauth_revoke_path,
          params: { token: access_token, token_type_hint: "access_token" },
          headers: { "Authorization" => auth_header }

        assert_response :success

        # Verify token is now inactive
        post oauth_introspect_path,
          params: { token: access_token },
          headers: { "Authorization" => auth_header }

        introspection = JSON.parse(response.body)
        assert_equal false, introspection["active"]
      end

      test "endpoints return 404 when OAuth not enabled" do
        ActionMCP.configuration.authentication_methods = [ "jwt" ]

        post oauth_token_path, params: { grant_type: "authorization_code" }
        assert_response :not_found

        post oauth_introspect_path, params: { token: "test" }
        assert_response :not_found

        post oauth_revoke_path, params: { token: "test" }
        assert_response :not_found
      end

      private

      def get_authorization_code
        get oauth_authorize_path, params: {
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          response_type: "code",
          scope: "mcp:tools"
        }

        redirect_url = URI.parse(response.location)
        query_params = CGI.parse(redirect_url.query)
        query_params["code"].first
      end

      def get_access_token
        code = get_authorization_code

        post oauth_token_path, params: {
          grant_type: "authorization_code",
          code: code,
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          client_secret: "test_secret"
        }

        token_response = JSON.parse(response.body)
        token_response["access_token"]
      end
    end
  end
end
