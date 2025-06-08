# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module OAuth
    class MetadataControllerTest < ActionDispatch::IntegrationTest
      include Engine.routes.url_helpers

      setup do
        @original_auth_methods = ActionMCP.configuration.authentication_methods
        @original_oauth_config = ActionMCP.configuration.oauth_config
      end

      teardown do
        ActionMCP.configuration.authentication_methods = @original_auth_methods
        ActionMCP.configuration.oauth_config = @original_oauth_config
      end

      test "authorization_server endpoint returns 404 when OAuth not enabled" do
        ActionMCP.configuration.authentication_methods = [ "jwt" ]

        get oauth_authorization_server_metadata_path
        assert_response :not_found
      end

      test "protected_resource endpoint returns 404 when OAuth not enabled" do
        ActionMCP.configuration.authentication_methods = [ "jwt" ]

        get oauth_protected_resource_metadata_path
        assert_response :not_found
      end

      test "authorization_server endpoint returns metadata when OAuth enabled" do
        ActionMCP.configuration.authentication_methods = [ "oauth" ]
        ActionMCP.configuration.oauth_config = {
          "issuer_url" => "https://example.com",
          "scopes_supported" => [ "mcp:tools", "mcp:resources" ],
          "pkce_required" => true
        }

        get oauth_authorization_server_metadata_path
        assert_response :success
        assert_equal "application/json", response.media_type

        metadata = JSON.parse(response.body)
        assert_equal "https://example.com", metadata["issuer"]
        assert_equal "https://example.com/oauth/authorize", metadata["authorization_endpoint"]
        assert_equal "https://example.com/oauth/token", metadata["token_endpoint"]
        assert_equal "https://example.com/oauth/introspect", metadata["introspection_endpoint"]
        assert_equal "https://example.com/oauth/revoke", metadata["revocation_endpoint"]
        assert_equal [ "code" ], metadata["response_types_supported"]
        assert_equal [ "authorization_code" ], metadata["grant_types_supported"]
        assert_equal [ "mcp:tools", "mcp:resources" ], metadata["scopes_supported"]
        assert_equal [ "S256" ], metadata["code_challenge_methods_supported"]
      end

      test "authorization_server metadata includes optional fields when configured" do
        ActionMCP.configuration.authentication_methods = [ "oauth" ]
        ActionMCP.configuration.oauth_config = {
          "issuer_url" => "https://example.com",
          "enable_dynamic_registration" => true,
          "enable_refresh_tokens" => true,
          "enable_client_credentials" => true,
          "allow_public_clients" => true,
          "jwks_uri" => "https://example.com/.well-known/jwks.json"
        }

        get oauth_authorization_server_metadata_path
        assert_response :success

        metadata = JSON.parse(response.body)
        assert_equal "https://example.com/oauth/register", metadata["registration_endpoint"]
        assert_includes metadata["grant_types_supported"], "refresh_token"
        assert_includes metadata["grant_types_supported"], "client_credentials"
        assert_includes metadata["token_endpoint_auth_methods_supported"], "none"
        assert_equal "https://example.com/.well-known/jwks.json", metadata["jwks_uri"]
      end

      test "protected_resource endpoint returns metadata when OAuth enabled" do
        ActionMCP.configuration.authentication_methods = [ "oauth" ]
        ActionMCP.configuration.oauth_config = {
          "issuer_url" => "https://example.com",
          "scopes_supported" => [ "mcp:tools", "mcp:resources", "mcp:prompts" ]
        }

        get oauth_protected_resource_metadata_path
        assert_response :success
        assert_equal "application/json", response.media_type

        metadata = JSON.parse(response.body)
        assert_equal "https://example.com", metadata["resource"]
        assert_equal [ "https://example.com" ], metadata["authorization_servers"]
        assert_equal [ "mcp:tools", "mcp:resources", "mcp:prompts" ], metadata["scopes_supported"]
        assert_equal [ "header" ], metadata["bearer_methods_supported"]
        assert_includes metadata["resource_documentation"], "/docs/api"
      end

      test "metadata uses request base_url when issuer_url not configured" do
        ActionMCP.configuration.authentication_methods = [ "oauth" ]
        ActionMCP.configuration.oauth_config = {}

        get oauth_authorization_server_metadata_path
        assert_response :success

        metadata = JSON.parse(response.body)
        assert_equal "http://www.example.com", metadata["issuer"]
        assert_equal "http://www.example.com/oauth/authorize", metadata["authorization_endpoint"]
      end

      test "metadata includes default scopes when none configured" do
        ActionMCP.configuration.authentication_methods = [ "oauth" ]
        ActionMCP.configuration.oauth_config = {}

        get oauth_authorization_server_metadata_path
        assert_response :success

        metadata = JSON.parse(response.body)
        assert_equal [ "mcp:tools", "mcp:resources", "mcp:prompts" ], metadata["scopes_supported"]
      end

      test "code_challenge_methods_supported includes plain when configured" do
        ActionMCP.configuration.authentication_methods = [ "oauth" ]
        ActionMCP.configuration.oauth_config = {
          "pkce_required" => true,
          "allow_plain_pkce" => true
        }

        get oauth_authorization_server_metadata_path
        assert_response :success

        metadata = JSON.parse(response.body)
        assert_includes metadata["code_challenge_methods_supported"], "S256"
        assert_includes metadata["code_challenge_methods_supported"], "plain"
      end
    end
  end
end
