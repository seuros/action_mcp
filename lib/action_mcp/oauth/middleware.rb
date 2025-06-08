# frozen_string_literal: true

module ActionMCP
  module OAuth
    # OAuth middleware that integrates with Omniauth for request authentication
    # Handles Bearer token validation for API requests
    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        # Skip OAuth processing for non-MCP requests or if OAuth not configured
        return @app.call(env) unless should_process_oauth?(request)


        # Validate Bearer token for API requests
        if bearer_token = extract_bearer_token(request)
          validate_oauth_token(request, bearer_token)
        end

        @app.call(env)
      rescue ActionMCP::OAuth::Error => e
        oauth_error_response(e)
      end

      private

      def should_process_oauth?(request)
        # Check if OAuth is enabled in configuration
        auth_methods = ActionMCP.configuration.authentication_methods
        return false unless auth_methods&.include?("oauth")

        # Process all MCP requests (ActionMCP serves at root "/") and OAuth-related paths
        true
      end


      def extract_bearer_token(request)
        auth_header = request.headers["Authorization"] || request.headers["authorization"]
        return nil unless auth_header&.start_with?("Bearer ")

        auth_header.split(" ", 2).last
      end

      def validate_oauth_token(request, token)
        # Use the OAuth provider for token introspection
        token_info = ActionMCP::OAuth::Provider.introspect_token(token)

        if token_info && token_info[:active]
          # Store OAuth token info in request environment for Gateway
          request.env["action_mcp.oauth_token_info"] = token_info
          request.env["action_mcp.oauth_token"] = token
        else
          raise ActionMCP::OAuth::InvalidTokenError, "Invalid or expired OAuth token"
        end
      end

      def oauth_error_response(error)
        status = case error
        when ActionMCP::OAuth::InvalidTokenError
                  401
        when ActionMCP::OAuth::InsufficientScopeError
                  403
        else
                  400
        end

        headers = {
          "Content-Type" => "application/json",
          "WWW-Authenticate" => www_authenticate_header(error)
        }

        body = {
          error: error.oauth_error_code,
          error_description: error.message
        }.to_json

        [ status, headers, [ body ] ]
      end

      def www_authenticate_header(error)
        params = []
        params << 'realm="MCP API"'

        case error
        when ActionMCP::OAuth::InvalidTokenError
          params << 'error="invalid_token"'
        when ActionMCP::OAuth::InsufficientScopeError
          params << 'error="insufficient_scope"'
          params << "scope=\"#{error.required_scope}\"" if error.required_scope
        end

        "Bearer #{params.join(', ')}"
      end
    end
  end
end
