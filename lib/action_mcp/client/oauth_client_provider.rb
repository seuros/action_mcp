# frozen_string_literal: true

require "faraday"
require "pkce_challenge"
require "securerandom"
require "uri"
require "json"

module ActionMCP
  module Client
    # OAuth client provider for MCP client authentication
    # Implements OAuth 2.1 authorization code flow with PKCE
    class OauthClientProvider
      class AuthenticationError < StandardError; end
      class TokenExpiredError < StandardError; end
      attr_reader :redirect_url, :client_metadata, :authorization_server_url

      def initialize(
        authorization_server_url:,
        redirect_url:,
        client_metadata: {},
        storage: nil,
        logger: ActionMCP.logger
      )
        @authorization_server_url = URI(authorization_server_url)
        @redirect_url = URI(redirect_url)
        @client_metadata = default_client_metadata.merge(client_metadata)
        @storage = storage || MemoryStorage.new
        @logger = logger
        @http_client = build_http_client
      end

      # Get current access token for authorization headers
      def access_token
        tokens = current_tokens
        return nil unless tokens

        if token_expired?(tokens)
          refresh_tokens! if tokens[:refresh_token]
          tokens = current_tokens
        end

        tokens&.dig(:access_token)
      end

      # Check if client has valid authentication
      def authenticated?
        !access_token.nil?
      end

      # Start OAuth authorization flow
      def start_authorization_flow(scope: nil, state: nil)
        # Generate PKCE challenge
        pkce = PkceChallenge.challenge
        code_verifier = pkce.code_verifier
        code_challenge = pkce.code_challenge
        @storage.save_code_verifier(code_verifier)

        # Build authorization URL
        auth_params = {
          response_type: "code",
          client_id: client_id,
          redirect_uri: @redirect_url.to_s,
          code_challenge: code_challenge,
          code_challenge_method: "S256"
        }
        auth_params[:scope] = scope if scope
        auth_params[:state] = state if state

        authorization_url = build_url(server_metadata[:authorization_endpoint], auth_params)

        log_debug("Starting OAuth flow: #{authorization_url}")
        authorization_url
      end

      # Complete OAuth flow with authorization code
      def complete_authorization_flow(authorization_code, state: nil)
        code_verifier = @storage.load_code_verifier
        raise AuthenticationError, "No code verifier found" unless code_verifier

        # Exchange code for tokens
        token_params = {
          grant_type: "authorization_code",
          code: authorization_code,
          redirect_uri: @redirect_url.to_s,
          code_verifier: code_verifier,
          client_id: client_id
        }

        response = @http_client.post(server_metadata[:token_endpoint]) do |req|
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.headers["Accept"] = "application/json"
          req.body = URI.encode_www_form(token_params)
        end

        handle_token_response(response)
      end

      # Refresh access token using refresh token
      def refresh_tokens!
        tokens = current_tokens
        refresh_token = tokens&.dig(:refresh_token)
        raise TokenExpiredError, "No refresh token available" unless refresh_token

        token_params = {
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: client_id
        }

        response = @http_client.post(server_metadata[:token_endpoint]) do |req|
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.headers["Accept"] = "application/json"
          req.body = URI.encode_www_form(token_params)
        end

        handle_token_response(response)
      end

      # Clear stored tokens (logout)
      def clear_tokens!
        @storage.clear_tokens
        @storage.clear_code_verifier if @storage.respond_to?(:clear_code_verifier)
        log_debug("Cleared OAuth tokens and code verifier")
      end

      # Get client information for registration
      def client_information
        @storage.load_client_information
      end

      # Save client information after registration
      def save_client_information(client_info)
        @storage.save_client_information(client_info)
      end

      # Get authorization headers for HTTP requests
      def authorization_headers
        token = access_token
        return {} unless token

        { "Authorization" => "Bearer #{token}" }
      end

      private

      def current_tokens
        @storage.load_tokens
      end

      def save_tokens(tokens)
        @storage.save_tokens(tokens)
      end

      def token_expired?(tokens)
        expires_at = tokens[:expires_at]
        return false unless expires_at

        Time.at(expires_at) <= Time.now + 30 # 30 second buffer
      end

      def client_id
        client_info = client_information
        client_info&.dig(:client_id) || @client_metadata[:client_id]
      end

      def server_metadata
        @server_metadata ||= fetch_server_metadata
      end

      def fetch_server_metadata
        well_known_url = @authorization_server_url.dup
        well_known_url.path = "/.well-known/oauth-authorization-server"

        response = @http_client.get(well_known_url)
        raise AuthenticationError, "Failed to fetch server metadata: #{response.status}" unless response.success?

        JSON.parse(response.body, symbolize_names: true)
      end

      def handle_token_response(response)
        unless response.success?
          error_body = begin
            JSON.parse(response.body)
          rescue StandardError
            {}
          end
          error_msg = error_body["error_description"] || error_body["error"] || "Token request failed"
          raise AuthenticationError, "#{error_msg} (#{response.status})"
        end

        token_data = JSON.parse(response.body, symbolize_names: true)

        # Calculate token expiration
        token_data[:expires_at] = Time.now.to_i + token_data[:expires_in].to_i if token_data[:expires_in]

        save_tokens(token_data)
        log_debug("OAuth tokens obtained successfully")
        token_data
      end

      def build_url(base_url, params)
        uri = URI(base_url)
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      def build_http_client
        Faraday.new do |f|
          f.headers["User-Agent"] = "ActionMCP-OAuth/#{ActionMCP.gem_version}"
          f.options.timeout = 30
          f.options.open_timeout = 10
          f.adapter :net_http
        end
      end

      def default_client_metadata
        {
          client_name: "ActionMCP Client",
          client_uri: "https://github.com/anthropics/action_mcp",
          redirect_uris: [ @redirect_url.to_s ],
          grant_types: %w[authorization_code refresh_token],
          response_types: [ "code" ],
          token_endpoint_auth_method: "none", # Public client
          code_challenge_methods_supported: [ "S256" ]
        }
      end

      def log_debug(message)
        @logger.debug("[ActionMCP::OAuthClientProvider] #{message}")
      end
    end
  end
end
