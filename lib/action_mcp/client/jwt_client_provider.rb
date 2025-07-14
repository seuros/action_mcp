# frozen_string_literal: true

require "json"
require "base64"

module ActionMCP
  module Client
    # JWT client provider for MCP client authentication
    # Provides clean JWT token management for ActionMCP client connections
    class JwtClientProvider
      class AuthenticationError < StandardError; end
      class TokenExpiredError < StandardError; end

      attr_reader :storage

      def initialize(token: nil, storage: nil, logger: ActionMCP.logger)
        @storage = storage || MemoryStorage.new
        @logger = logger

        # If token provided during initialization, store it
        if token
          save_token(token)
        end
      end

      # Check if client has valid authentication
      def authenticated?
        token = current_token
        return false unless token

        !token_expired?(token)
      end

      # Get authorization headers for HTTP requests
      def authorization_headers
        token = current_token
        return {} unless token

        if token_expired?(token)
          log_debug("JWT token expired")
          clear_tokens!
          return {}
        end

        { "Authorization" => "Bearer #{token}" }
      end

      # Set/update the JWT token
      def set_token(token)
        save_token(token)
        log_debug("JWT token updated")
      end

      # Clear stored tokens (logout)
      def clear_tokens!
        @storage.clear_token
        log_debug("Cleared JWT token")
      end

      # Get current valid token
      def access_token
        token = current_token
        return nil unless token
        return nil if token_expired?(token)
        token
      end

      private

      def current_token
        @storage.load_token
      end

      def save_token(token)
        @storage.save_token(token)
      end

      def token_expired?(token)
        return false unless token

        begin
          payload = decode_jwt_payload(token)
          exp = payload["exp"]
          return false unless exp

          # Add 30 second buffer for clock skew
          Time.at(exp) <= Time.now + 30
        rescue => e
          log_debug("Error checking token expiration: #{e.message}")
          true # Treat invalid tokens as expired
        end
      end

      def decode_jwt_payload(token)
        # Split JWT into parts
        parts = token.split(".")
        raise AuthenticationError, "Invalid JWT format" unless parts.length == 3

        # Decode payload (second part)
        payload_base64 = parts[1]
        # Add padding if needed
        payload_base64 += "=" * (4 - payload_base64.length % 4) if payload_base64.length % 4 != 0

        payload_json = Base64.urlsafe_decode64(payload_base64)
        JSON.parse(payload_json)
      rescue => e
        raise AuthenticationError, "Failed to decode JWT: #{e.message}"
      end

      def log_debug(message)
        @logger.debug("[ActionMCP::JwtClientProvider] #{message}")
      end

      # Simple memory storage for JWT tokens
      class MemoryStorage
        def initialize
          @token = nil
        end

        def save_token(token)
          @token = token
        end

        def load_token
          @token
        end

        def clear_token
          @token = nil
        end
      end
    end
  end
end
