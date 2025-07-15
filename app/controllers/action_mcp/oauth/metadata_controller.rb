# frozen_string_literal: true

module ActionMCP
  module OAuth
    # Controller for OAuth 2.1 metadata endpoints
    # Provides server discovery information as per RFC 8414
    class MetadataController < ActionController::Base
      before_action :check_oauth_enabled

      # GET /.well-known/oauth-authorization-server
      # Returns OAuth Authorization Server Metadata as per RFC 8414
      def authorization_server
        metadata = {
          issuer: issuer_url,
          authorization_endpoint: authorization_endpoint,
          token_endpoint: token_endpoint,
          introspection_endpoint: introspection_endpoint,
          revocation_endpoint: revocation_endpoint,
          response_types_supported: response_types_supported,
          grant_types_supported: grant_types_supported,
          token_endpoint_auth_methods_supported: token_endpoint_auth_methods_supported,
          scopes_supported: scopes_supported,
          code_challenge_methods_supported: code_challenge_methods_supported,
          service_documentation: service_documentation
        }

        # Add optional fields based on configuration
        metadata[:registration_endpoint] = registration_endpoint if oauth_config[:enable_dynamic_registration]

        metadata[:jwks_uri] = oauth_config[:jwks_uri] if oauth_config[:jwks_uri]

        render json: metadata
      end

      # GET /.well-known/oauth-protected-resource
      # Returns Protected Resource Metadata as per RFC 8705
      def protected_resource
        metadata = {
          resource: issuer_url,
          authorization_servers: [ issuer_url ],
          scopes_supported: scopes_supported,
          bearer_methods_supported: [ "header" ],
          resource_documentation: resource_documentation
        }

        render json: metadata
      end

      private

      def check_oauth_enabled
        auth_methods = ActionMCP.configuration.authentication_methods
        return if auth_methods&.include?("oauth")

        head :not_found
      end

      def oauth_config
        @oauth_config ||= HashWithIndifferentAccess.new(ActionMCP.configuration.oauth_config || {})
      end

      def issuer_url
        @issuer_url ||= oauth_config.fetch(:issuer_url, request.base_url)
      end

      def authorization_endpoint
        "#{issuer_url}/oauth/authorize"
      end

      def token_endpoint
        "#{issuer_url}/oauth/token"
      end

      def introspection_endpoint
        "#{issuer_url}/oauth/introspect"
      end

      def revocation_endpoint
        "#{issuer_url}/oauth/revoke"
      end

      def registration_endpoint
        "#{issuer_url}/oauth/register"
      end

      def response_types_supported
        [ "code" ]
      end

      def grant_types_supported
        grants = [ "authorization_code" ]
        grants << "refresh_token" if oauth_config[:enable_refresh_tokens]
        grants << "client_credentials" if oauth_config[:enable_client_credentials]
        grants
      end

      def token_endpoint_auth_methods_supported
        methods = %w[client_secret_basic client_secret_post]
        methods << "none" if oauth_config[:allow_public_clients]
        methods
      end

      def scopes_supported
        oauth_config.fetch(:scopes_supported, [ "mcp:tools", "mcp:resources", "mcp:prompts" ])
      end

      def code_challenge_methods_supported
        methods = []
        if oauth_config[:pkce_required] || oauth_config[:pkce_supported]
          methods << "S256"
          methods << "plain" if oauth_config[:allow_plain_pkce]
        end
        methods
      end

      def service_documentation
        oauth_config.fetch(:service_documentation, "#{request.base_url}/docs")
      end

      def resource_documentation
        oauth_config.fetch(:resource_documentation, "#{request.base_url}/docs/api")
      end
    end
  end
end
