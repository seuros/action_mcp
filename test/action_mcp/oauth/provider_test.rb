# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module OAuth
    class ProviderTest < ActiveSupport::TestCase
      setup do
        @original_oauth_config = ActionMCP.configuration.oauth_config
        ActionMCP.configuration.oauth_config = {
          "pkce_required" => true,
          "enable_refresh_tokens" => true,
          "scopes_supported" => [ "mcp:tools", "mcp:resources" ],
          "access_token_expires_in" => 3600,
          "refresh_token_expires_in" => 86400
        }

        # Clear storage before each test
        Provider.send(:storage).clear_all

        # Clear cached config
        Provider.instance_variable_set(:@oauth_config, nil)

        # Register a default client for testing
        Provider.register_client(
          client_id: "test_client",
          client_secret: "test_secret", # Add a secret for client_credentials_grant
          redirect_uris: [ "https://example.com/callback" ],
          grant_types: [ "authorization_code", "refresh_token", "client_credentials" ],
          response_types: [ "code" ],
          token_endpoint_auth_method: "client_secret_basic"
        )
      end

      teardown do
        ActionMCP.configuration.oauth_config = @original_oauth_config
      end

      test "generate_authorization_code creates valid code" do
        code = Provider.generate_authorization_code(
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          scope: "mcp:tools",
          code_challenge: "test_challenge",
          code_challenge_method: "S256",
          user_id: "user123"
        )

        assert_not_nil code
        assert code.length > 20

        # Verify code can be retrieved
        code_data = Provider.send(:retrieve_authorization_code, code)
        assert_equal "test_client", code_data[:client_id]
        assert_equal "user123", code_data[:user_id]
      end

      test "exchange_code_for_token validates PKCE correctly" do
        # Generate code with PKCE challenge
        code_verifier = "test_verifier_123456789012345678901234567890"
        code_challenge = Base64.urlsafe_encode64(
          Digest::SHA256.digest(code_verifier), padding: false
        )

        code = Provider.generate_authorization_code(
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          scope: "mcp:tools",
          code_challenge: code_challenge,
          code_challenge_method: "S256",
          user_id: "user123"
        )

        # Exchange with correct verifier
        token_response = Provider.exchange_code_for_token(
          code: code,
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          code_verifier: code_verifier,
          client_secret: "test_secret"
        )

        assert_equal "Bearer", token_response[:token_type]
        assert_equal 3600, token_response[:expires_in]
        assert_equal "mcp:tools", token_response[:scope]
        assert_not_nil token_response[:access_token]
        assert_not_nil token_response[:refresh_token]
      end

      test "exchange_code_for_token fails with wrong PKCE verifier" do
        code_challenge = Base64.urlsafe_encode64(
          Digest::SHA256.digest("correct_verifier"), padding: false
        )

        code = Provider.generate_authorization_code(
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          scope: "mcp:tools",
          code_challenge: code_challenge,
          code_challenge_method: "S256",
          user_id: "user123"
        )

        assert_raises(InvalidGrantError) do
          Provider.exchange_code_for_token(
            code: code,
            client_id: "test_client",
            redirect_uri: "https://example.com/callback",
            code_verifier: "wrong_verifier",
            client_secret: "test_secret"
          )
        end
      end

      test "exchange_code_for_token validates redirect_uri" do
        code = Provider.generate_authorization_code(
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          scope: "mcp:tools",
          user_id: "user123"
        )

        assert_raises(InvalidGrantError) do
          Provider.exchange_code_for_token(
            code: code,
            client_id: "test_client",
            redirect_uri: "https://malicious.com/callback",
            client_secret: "test_secret"
          )
        end
      end

      test "refresh_access_token works correctly" do
        # Create initial token
        code = Provider.generate_authorization_code(
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          scope: "mcp:tools mcp:resources",
          user_id: "user123"
        )

        initial_response = Provider.exchange_code_for_token(
          code: code,
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          client_secret: "test_secret"
        )

        # Refresh the token
        refresh_response = Provider.refresh_access_token(
          refresh_token: initial_response[:refresh_token],
          client_id: "test_client",
          client_secret: "test_secret"
        )

        assert_equal "Bearer", refresh_response[:token_type]
        assert_equal "mcp:tools mcp:resources", refresh_response[:scope]
        assert_not_equal initial_response[:access_token], refresh_response[:access_token]
      end

      test "introspect_token returns correct info for valid token" do
        code = Provider.generate_authorization_code(
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          scope: "mcp:tools",
          user_id: "user123"
        )

        token_response = Provider.exchange_code_for_token(
          code: code,
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          client_secret: "test_secret"
        )

        introspection = Provider.introspect_token(token_response[:access_token])

        assert introspection[:active]
        assert_equal "test_client", introspection[:client_id]
        assert_equal "mcp:tools", introspection[:scope]
        assert_equal "user123", introspection[:user_id]
        assert_equal "Bearer", introspection[:token_type]
      end

      test "introspect_token returns inactive for invalid token" do
        introspection = Provider.introspect_token("invalid_token")
        assert_equal false, introspection[:active]
      end

      test "revoke_token removes access token" do
        code = Provider.generate_authorization_code(
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          scope: "mcp:tools",
          user_id: "user123"
        )

        token_response = Provider.exchange_code_for_token(
          code: code,
          client_id: "test_client",
          redirect_uri: "https://example.com/callback",
          client_secret: "test_secret"
        )

        # Token should be active before revocation
        introspection = Provider.introspect_token(token_response[:access_token])
        assert introspection[:active]

        # Revoke token
        result = Provider.revoke_token(token_response[:access_token])
        assert result

        # Token should be inactive after revocation
        introspection = Provider.introspect_token(token_response[:access_token])
        assert_equal false, introspection[:active]
      end

      test "client_credentials_grant works when enabled" do
        ActionMCP.configuration.oauth_config["enable_client_credentials"] = true

        token_response = Provider.client_credentials_grant(
          client_id: "test_client",
          client_secret: "test_secret",
          scope: "mcp:tools"
        )

        assert_equal "Bearer", token_response[:token_type]
        assert_equal "mcp:tools", token_response[:scope]
        assert_not_nil token_response[:access_token]
        assert_nil token_response[:refresh_token] # No refresh token for client credentials
      end

      test "client_credentials_grant fails when disabled" do
        # Create new config without client credentials
        ActionMCP.configuration.oauth_config = {
          "pkce_required" => true,
          "enable_refresh_tokens" => true,
          "enable_client_credentials" => false,
          "scopes_supported" => [ "mcp:tools", "mcp:resources" ],
          "access_token_expires_in" => 3600,
          "refresh_token_expires_in" => 86400
        }

        # Clear cached config after changing it
        Provider.instance_variable_set(:@oauth_config, nil)

        assert_raises(UnsupportedGrantTypeError) do
          Provider.client_credentials_grant(
            client_id: "test_client",
            client_secret: "test_secret"
          )
        end
      end

      test "validates scope correctly" do
        assert_raises(InvalidScopeError) do
          Provider.generate_authorization_code(
            client_id: "test_client",
            redirect_uri: "https://example.com/callback",
            scope: "invalid:scope",
            user_id: "user123"
          )
        end
      end

      test "expired codes are rejected" do
        # Travel to past to create expired code
        travel_to 1.hour.ago do
          @expired_code = Provider.generate_authorization_code(
            client_id: "test_client",
            redirect_uri: "https://example.com/callback",
            scope: "mcp:tools",
            user_id: "user123"
          )
        end

        assert_raises(InvalidGrantError) do
          Provider.exchange_code_for_token(
            code: @expired_code,
            client_id: "test_client",
            redirect_uri: "https://example.com/callback",
            client_secret: "test_secret"
          )
        end
      end
    end
  end
end
