# frozen_string_literal: true

require "omniauth-oauth2"

module ActionMCP
  module Omniauth
    # MCP-specific Omniauth strategy for OAuth 2.1 authentication
    # This strategy integrates with ActionMCP's configuration system and provider interface
    class MCPStrategy < ::OmniAuth::Strategies::OAuth2
      # Strategy name used in configuration
      option :name, "mcp"

      # Default OAuth options with MCP-specific settings
      option :client_options, {
        authorize_url: "/oauth/authorize",
        token_url: "/oauth/token",
        auth_scheme: :request_body
      }

      # OAuth 2.1 compliance - PKCE is required
      option :pkce, true

      # Default scopes for MCP access
      option :scope, "mcp:tools mcp:resources mcp:prompts"

      # Use authorization code grant flow
      option :response_type, "code"

      # OAuth server metadata discovery
      option :discovery, true

      def initialize(app, *args, &block)
        super

        # Load configuration from ActionMCP if available
        configure_from_mcp_config if defined?(ActionMCP)
      end

      # User info from OAuth token response or userinfo endpoint
      def raw_info
        @raw_info ||= begin
          if options.userinfo_url
            access_token.get(options.userinfo_url).parsed
          else
            # Extract user info from token response or use minimal info
            token_response = access_token.token
            {
              "sub" => access_token.params["user_id"] || access_token.token,
              "scope" => access_token.params["scope"] || options.scope
            }
          end
        end
      rescue ::OAuth2::Error => e
        log(:error, "Failed to fetch user info: #{e.message}")
        {}
      end

      # User ID for Omniauth
      uid { raw_info["sub"] || raw_info["user_id"] }

      # User info hash
      info do
        {
          name: raw_info["name"],
          email: raw_info["email"],
          username: raw_info["username"] || raw_info["preferred_username"]
        }
      end

      # Extra credentials and token info
      extra do
        {
          "raw_info" => raw_info,
          "scope" => access_token.params["scope"],
          "token_type" => access_token.params["token_type"] || "Bearer"
        }
      end

      # OAuth server metadata discovery
      def discovery_info
        @discovery_info ||= begin
          if options.discovery && options.client_options.site
            discovery_url = "#{options.client_options.site}/.well-known/oauth-authorization-server"
            response = client.request(:get, discovery_url)
            JSON.parse(response.body)
          end
        rescue StandardError => e
          log(:warn, "OAuth discovery failed: #{e.message}")
          {}
        end
      end

      # Override client to use discovered endpoints if available
      def client
        @client ||= begin
          if discovery_info.any?
            options.client_options.merge!(
              authorize_url: discovery_info["authorization_endpoint"],
              token_url: discovery_info["token_endpoint"]
            ) if discovery_info["authorization_endpoint"] && discovery_info["token_endpoint"]
          end
          super
        end
      end

      # Token validation for API requests (not callback flow)
      def self.validate_token(token, options = {})
        strategy = new(nil, options)
        strategy.validate_token(token)
      end

      def validate_token(token)
        # Validate access token with OAuth server
        return nil unless token

        begin
          response = client.request(:post, options.introspection_url || "/oauth/introspect", {
            body: { token: token },
            headers: { "Content-Type" => "application/x-www-form-urlencoded" }
          })

          token_info = JSON.parse(response.body)
          return nil unless token_info["active"]

          token_info
        rescue StandardError => e
          log(:error, "Token validation failed: #{e.message}")
          nil
        end
      end

      private

      # Configure strategy from ActionMCP configuration
      def configure_from_mcp_config
        oauth_config = ActionMCP.configuration.oauth_config
        return unless oauth_config.is_a?(Hash)

        # Set client options from MCP config
        if oauth_config["issuer_url"]
          options.client_options[:site] = oauth_config["issuer_url"]
        end

        if oauth_config["client_id"]
          options.client_id = oauth_config["client_id"]
        end

        if oauth_config["client_secret"]
          options.client_secret = oauth_config["client_secret"]
        end

        if oauth_config["scopes_supported"]
          options.scope = Array(oauth_config["scopes_supported"]).join(" ")
        end

        # Enable PKCE if required (OAuth 2.1 compliance)
        if oauth_config["pkce_required"]
          options.pkce = true
        end

        # Set userinfo endpoint if provided
        if oauth_config["userinfo_endpoint"]
          options.userinfo_url = oauth_config["userinfo_endpoint"]
        end

        # Set token introspection endpoint
        if oauth_config["introspection_endpoint"]
          options.introspection_url = oauth_config["introspection_endpoint"]
        end
      end
    end
  end
end

# Register the strategy with Omniauth
OmniAuth.config.add_camelization "mcp", "MCP"
