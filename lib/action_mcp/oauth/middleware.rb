# frozen_string_literal: true

require_relative "error"

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

        # Skip OAuth processing for metadata endpoints
        return @app.call(env) if request.path.start_with?("/.well-known/") || request.path.start_with?("/oauth/")

        # Skip OAuth processing for initialization-related requests
        return @app.call(env) if initialization_related_request?(request)

        # Validate Bearer token for API requests
        if (bearer_token = extract_bearer_token(request))
          validate_oauth_token(request, bearer_token)
        end

        @app.call(env)
      rescue ActionMCP::OAuth::Error => e
        oauth_error_response(e)
      end

      private

      def should_process_oauth?(_request)
        # Check if OAuth is enabled in configuration
        auth_methods = ActionMCP.configuration.authentication_methods
        return false unless auth_methods&.include?("oauth")

        # Process all MCP requests (ActionMCP serves at root "/") and OAuth-related paths
        true
      end

      def initialization_related_request?(request)
        # Only check JSON-RPC POST requests to MCP endpoints
        # The path might include the mount path (e.g., /action_mcp/ or just /)
        return false unless request.post? && request.content_type&.include?("application/json")

        # Check if this is an MCP endpoint (ends with / or is the root)
        path = request.path
        return false unless path == "/" || path.match?(%r{/action_mcp/?$})

        # Read and parse the request body
        body = request.body.read
        request.body.rewind # Reset for subsequent reads

        json = JSON.parse(body)
        method = json["method"]

        # Check if it's an initialization-related method
        %w[initialize notifications/initialized].include?(method)
      rescue JSON::ParserError, StandardError
        false
      end

      def extract_bearer_token(request)
        auth_header = request.headers["Authorization"] || request.headers["authorization"]
        return nil unless auth_header&.start_with?("Bearer ")

        auth_header.split(" ", 2).last
      end

      def validate_oauth_token(request, token)
        # Use the OAuth provider for token introspection
        token_info = ActionMCP::OAuth::Provider.introspect_token(token)

        unless token_info && token_info[:active]
          raise ActionMCP::OAuth::InvalidTokenError, "Invalid or expired OAuth token"
        end

        # Store OAuth token info in request environment for Gateway
        request.env["action_mcp.oauth_token_info"] = token_info
        request.env["action_mcp.oauth_token"] = token
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
