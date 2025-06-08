# frozen_string_literal: true

require "securerandom"
require "digest"
require "base64"

module ActionMCP
  module OAuth
    # OAuth 2.1 Provider implementation
    # Handles authorization codes, access tokens, refresh tokens, and token validation
    class Provider
      class << self
        # Generate authorization code for OAuth flow
        # @param client_id [String] OAuth client identifier
        # @param redirect_uri [String] Client redirect URI
        # @param scope [String] Requested scope
        # @param code_challenge [String] PKCE code challenge
        # @param code_challenge_method [String] PKCE challenge method (S256, plain)
        # @param user_id [String] User identifier
        # @return [String] Authorization code
        def generate_authorization_code(client_id:, redirect_uri:, scope:, code_challenge: nil, code_challenge_method: nil, user_id:)
          # Validate scope
          validate_scope(scope) if scope

          code = SecureRandom.urlsafe_base64(32)

          # Store authorization code with metadata
          store_authorization_code(code, {
            client_id: client_id,
            redirect_uri: redirect_uri,
            scope: scope,
            code_challenge: code_challenge,
            code_challenge_method: code_challenge_method,
            user_id: user_id,
            created_at: Time.current,
            expires_at: 10.minutes.from_now
          })

          code
        end

        # Exchange authorization code for access token
        # @param code [String] Authorization code
        # @param client_id [String] OAuth client identifier
        # @param client_secret [String] OAuth client secret (optional for public clients)
        # @param redirect_uri [String] Client redirect URI
        # @param code_verifier [String] PKCE code verifier
        # @return [Hash] Token response with access_token, token_type, expires_in, scope
        def exchange_code_for_token(code:, client_id:, client_secret: nil, redirect_uri:, code_verifier: nil)
          # Retrieve and validate authorization code
          code_data = retrieve_authorization_code(code)
          raise InvalidGrantError, "Invalid authorization code" unless code_data
          raise InvalidGrantError, "Authorization code expired" if code_data[:expires_at] < Time.current

          # Validate client
          validate_client(client_id, client_secret)

          # Validate redirect URI matches
          unless code_data[:redirect_uri] == redirect_uri
            raise InvalidGrantError, "Redirect URI mismatch"
          end

          # Validate client ID matches
          unless code_data[:client_id] == client_id
            raise InvalidGrantError, "Client ID mismatch"
          end

          # Validate PKCE if challenge was provided during authorization
          if code_data[:code_challenge]
            validate_pkce(code_data[:code_challenge], code_data[:code_challenge_method], code_verifier)
          end

          # Generate access token
          access_token = generate_access_token(
            client_id: client_id,
            scope: code_data[:scope],
            user_id: code_data[:user_id]
          )

          # Generate refresh token if enabled
          refresh_token = nil
          if oauth_config["enable_refresh_tokens"]
            refresh_token = generate_refresh_token(
              client_id: client_id,
              scope: code_data[:scope],
              user_id: code_data[:user_id],
              access_token: access_token
            )
          end

          # Remove used authorization code
          remove_authorization_code(code)

          # Return token response
          response = {
            access_token: access_token,
            token_type: "Bearer",
            expires_in: token_expires_in,
            scope: code_data[:scope]
          }
          response[:refresh_token] = refresh_token if refresh_token
          response
        end

        # Refresh access token using refresh token
        # @param refresh_token [String] Refresh token
        # @param client_id [String] OAuth client identifier
        # @param client_secret [String] OAuth client secret
        # @param scope [String] Requested scope (optional, must be subset of original)
        # @return [Hash] New token response
        def refresh_access_token(refresh_token:, client_id:, client_secret: nil, scope: nil)
          # Retrieve refresh token data
          token_data = retrieve_refresh_token(refresh_token)
          raise InvalidGrantError, "Invalid refresh token" unless token_data
          raise InvalidGrantError, "Refresh token expired" if token_data[:expires_at] < Time.current

          # Validate client
          validate_client(client_id, client_secret)

          # Validate client ID matches
          unless token_data[:client_id] == client_id
            raise InvalidGrantError, "Client ID mismatch"
          end

          # Validate scope if provided
          if scope
            requested_scopes = scope.split(" ")
            original_scopes = token_data[:scope].split(" ")
            unless (requested_scopes - original_scopes).empty?
              raise InvalidScopeError, "Requested scope exceeds original scope"
            end
          else
            scope = token_data[:scope]
          end

          # Revoke old access token
          revoke_access_token(token_data[:access_token]) if token_data[:access_token]

          # Generate new access token
          access_token = generate_access_token(
            client_id: client_id,
            scope: scope,
            user_id: token_data[:user_id]
          )

          # Update refresh token with new access token
          update_refresh_token(refresh_token, access_token)

          {
            access_token: access_token,
            token_type: "Bearer",
            expires_in: token_expires_in,
            scope: scope
          }
        end

        # Validate access token and return token info
        # @param access_token [String] Access token to validate
        # @return [Hash] Token info with active, client_id, scope, user_id, exp
        def introspect_token(access_token)
          token_data = retrieve_access_token(access_token)

          unless token_data
            return { active: false }
          end

          if token_data[:expires_at] < Time.current
            remove_access_token(access_token)
            return { active: false }
          end

          {
            active: true,
            client_id: token_data[:client_id],
            scope: token_data[:scope],
            user_id: token_data[:user_id],
            exp: token_data[:expires_at].to_i,
            iat: token_data[:created_at].to_i,
            token_type: "Bearer"
          }
        end

        # Revoke access or refresh token
        # @param token [String] Token to revoke
        # @param token_type_hint [String] Type hint: "access_token" or "refresh_token"
        # @return [Boolean] True if token was revoked
        def revoke_token(token, token_type_hint: nil)
          revoked = false

          # Try access token first if hint suggests it or no hint provided
          if token_type_hint == "access_token" || token_type_hint.nil?
            if retrieve_access_token(token)
              revoke_access_token(token)
              revoked = true
            end
          end

          # Try refresh token if not revoked yet
          if !revoked && (token_type_hint == "refresh_token" || token_type_hint.nil?)
            if retrieve_refresh_token(token)
              revoke_refresh_token(token)
              revoked = true
            end
          end

          revoked
        end

        # Client Credentials Grant (for server-to-server)
        # @param client_id [String] OAuth client identifier
        # @param client_secret [String] OAuth client secret
        # @param scope [String] Requested scope
        # @return [Hash] Token response
        def client_credentials_grant(client_id:, client_secret:, scope: nil)
          unless oauth_config["enable_client_credentials"]
            raise UnsupportedGrantTypeError, "Client credentials grant not supported"
          end

          # Validate client credentials
          validate_client(client_id, client_secret, require_secret: true)

          # Validate scope
          if scope
            validate_scope(scope)
          else
            scope = default_scope
          end

          # Generate access token (no user context for client credentials)
          access_token = generate_access_token(
            client_id: client_id,
            scope: scope,
            user_id: nil
          )

          {
            access_token: access_token,
            token_type: "Bearer",
            expires_in: token_expires_in,
            scope: scope
          }
        end

        private

        def oauth_config
          @oauth_config ||= ActionMCP.configuration.oauth_config || {}
        end

        def validate_client(client_id, client_secret, require_secret: false)
          # This should be implemented by the application
          # For now, we'll use a simple validation approach
          provider_class = oauth_config["provider"]
          if provider_class && provider_class.respond_to?(:validate_client)
            provider_class.validate_client(client_id, client_secret)
          elsif require_secret && client_secret.nil?
            raise InvalidClientError, "Client authentication required"
          end
          # Default: allow any client for development
        end

        def validate_pkce(code_challenge, method, code_verifier)
          raise InvalidGrantError, "Code verifier required" unless code_verifier

          case method
          when "S256"
            expected_challenge = Base64.urlsafe_encode64(
              Digest::SHA256.digest(code_verifier), padding: false
            )
            unless code_challenge == expected_challenge
              raise InvalidGrantError, "Invalid code verifier"
            end
          when "plain"
            unless oauth_config["allow_plain_pkce"]
              raise InvalidGrantError, "Plain PKCE not allowed"
            end
            unless code_challenge == code_verifier
              raise InvalidGrantError, "Invalid code verifier"
            end
          else
            raise InvalidGrantError, "Unsupported code challenge method"
          end
        end

        def validate_scope(scope)
          supported_scopes = oauth_config["scopes_supported"] || [ "mcp:tools", "mcp:resources", "mcp:prompts" ]
          requested_scopes = scope.split(" ")
          unsupported = requested_scopes - supported_scopes
          if unsupported.any?
            raise InvalidScopeError, "Unsupported scopes: #{unsupported.join(', ')}"
          end
        end

        def default_scope
          oauth_config["default_scope"] || "mcp:tools mcp:resources mcp:prompts"
        end

        def generate_access_token(client_id:, scope:, user_id:)
          token = SecureRandom.urlsafe_base64(32)

          store_access_token(token, {
            client_id: client_id,
            scope: scope,
            user_id: user_id,
            created_at: Time.current,
            expires_at: token_expires_in.seconds.from_now
          })

          token
        end

        def generate_refresh_token(client_id:, scope:, user_id:, access_token:)
          token = SecureRandom.urlsafe_base64(32)

          store_refresh_token(token, {
            client_id: client_id,
            scope: scope,
            user_id: user_id,
            access_token: access_token,
            created_at: Time.current,
            expires_at: refresh_token_expires_in.seconds.from_now
          })

          token
        end

        def token_expires_in
          oauth_config["access_token_expires_in"] || 3600 # 1 hour
        end

        def refresh_token_expires_in
          oauth_config["refresh_token_expires_in"] || 7.days.to_i # 1 week
        end

        # Storage methods - these delegate to a configurable storage backend
        def storage
          @storage ||= begin
            storage_class = oauth_config["storage"] || "ActionMCP::OAuth::MemoryStorage"
            storage_class = storage_class.constantize if storage_class.is_a?(String)
            storage_class.new
          end
        end

        def store_authorization_code(code, data)
          storage.store_authorization_code(code, data)
        end

        def retrieve_authorization_code(code)
          storage.retrieve_authorization_code(code)
        end

        def remove_authorization_code(code)
          storage.remove_authorization_code(code)
        end

        def store_access_token(token, data)
          storage.store_access_token(token, data)
        end

        def retrieve_access_token(token)
          storage.retrieve_access_token(token)
        end

        def remove_access_token(token)
          storage.remove_access_token(token)
        end

        def revoke_access_token(token)
          storage.remove_access_token(token)
        end

        def store_refresh_token(token, data)
          storage.store_refresh_token(token, data)
        end

        def retrieve_refresh_token(token)
          storage.retrieve_refresh_token(token)
        end

        def update_refresh_token(token, new_access_token)
          storage.update_refresh_token(token, new_access_token)
        end

        def revoke_refresh_token(token)
          storage.remove_refresh_token(token)
        end
      end
    end
  end
end
