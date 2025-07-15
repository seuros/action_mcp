# frozen_string_literal: true

require "ostruct"

module ActionMCP
  module OAuth
    # OAuth 2.1 endpoints controller
    # Handles authorization, token, introspection, and revocation endpoints
    class EndpointsController < ActionController::Base
      protect_from_forgery with: :null_session
      before_action :check_oauth_enabled

      # GET /oauth/authorize
      # Authorization endpoint for OAuth 2.1 authorization code flow
      def authorize
        # Extract parameters
        client_id = params[:client_id]
        redirect_uri = params[:redirect_uri]
        response_type = params[:response_type]
        scope = params[:scope]
        state = params[:state]
        code_challenge = params[:code_challenge]
        code_challenge_method = params[:code_challenge_method]

        # Validate required parameters
        if client_id.blank? || redirect_uri.blank? || response_type.blank?
          return render_error("invalid_request", "Missing required parameters")
        end

        # Validate response type
        unless response_type == "code"
          return render_error("unsupported_response_type", "Only authorization code flow supported")
        end

        # Validate PKCE if required
        if oauth_config["pkce_required"] && code_challenge.blank?
          return render_error("invalid_request", "PKCE required")
        end

        # In a real implementation, this would show a consent page
        # For now, we'll auto-approve for configured clients
        if auto_approve_client?(client_id)
          # Generate authorization code
          user_id = current_user&.id || "anonymous"

          begin
            code = ActionMCP::OAuth::Provider.generate_authorization_code(
              client_id: client_id,
              redirect_uri: redirect_uri,
              scope: scope || default_scope,
              code_challenge: code_challenge,
              code_challenge_method: code_challenge_method,
              user_id: user_id
            )

            # Redirect back to client with authorization code
            redirect_params = { code: code }
            redirect_params[:state] = state if state
            redirect_to "#{redirect_uri}?#{redirect_params.to_query}", allow_other_host: true
          rescue ActionMCP::OAuth::Error => e
            render_error(e.oauth_error_code, e.message)
          end
        else
          # In production, show consent page
          render_consent_page(client_id, redirect_uri, scope, state, code_challenge, code_challenge_method)
        end
      end

      # POST /oauth/token
      # Token endpoint for exchanging authorization codes and refreshing tokens
      def token
        grant_type = params[:grant_type]

        case grant_type
        when "authorization_code"
          handle_authorization_code_grant
        when "refresh_token"
          handle_refresh_token_grant
        when "client_credentials"
          handle_client_credentials_grant
        else
          render_token_error("unsupported_grant_type", "Unsupported grant type")
        end
      rescue ActionMCP::OAuth::Error => e
        render_token_error(e.oauth_error_code, e.message)
      end

      # POST /oauth/introspect
      # Token introspection endpoint (RFC 7662)
      def introspect
        token = params[:token]
        return render_introspection_error unless token

        # Authenticate client for introspection
        client_id, = extract_client_credentials
        return render_introspection_error unless client_id

        begin
          token_info = ActionMCP::OAuth::Provider.introspect_token(token)
          render json: token_info
        rescue ActionMCP::OAuth::Error
          render json: { active: false }
        end
      end

      # POST /oauth/revoke
      # Token revocation endpoint (RFC 7009)
      def revoke
        token = params[:token]
        token_type_hint = params[:token_type_hint]

        return head :bad_request unless token

        # Authenticate client
        client_id, = extract_client_credentials
        return head :unauthorized unless client_id

        begin
          ActionMCP::OAuth::Provider.revoke_token(token, token_type_hint: token_type_hint)
          head :ok
        rescue ActionMCP::OAuth::Error
          head :bad_request
        end
      end

      private

      def check_oauth_enabled
        auth_methods = ActionMCP.configuration.authentication_methods
        return if auth_methods&.include?("oauth")

        head :not_found
      end

      def oauth_config
        @oauth_config ||= ActionMCP.configuration.oauth_config || {}
      end

      def handle_authorization_code_grant
        code = params[:code]
        client_id = params[:client_id]
        client_secret = params[:client_secret]
        redirect_uri = params[:redirect_uri]
        code_verifier = params[:code_verifier]

        # Extract client credentials from Authorization header if not in params
        client_id, client_secret = extract_client_credentials if client_id.blank?

        return render_token_error("invalid_request", "Missing required parameters") if code.blank? || client_id.blank?

        token_response = ActionMCP::OAuth::Provider.exchange_code_for_token(
          code: code,
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: redirect_uri,
          code_verifier: code_verifier
        )

        render json: token_response
      end

      def handle_refresh_token_grant
        refresh_token = params[:refresh_token]
        scope = params[:scope]

        # Extract client credentials
        client_id, client_secret = extract_client_credentials
        client_id ||= params[:client_id]
        client_secret ||= params[:client_secret]

        if refresh_token.blank? || client_id.blank?
          return render_token_error("invalid_request",
                                    "Missing required parameters")
        end

        token_response = ActionMCP::OAuth::Provider.refresh_access_token(
          refresh_token: refresh_token,
          client_id: client_id,
          client_secret: client_secret,
          scope: scope
        )

        render json: token_response
      end

      def handle_client_credentials_grant
        scope = params[:scope]

        # Extract client credentials
        client_id, client_secret = extract_client_credentials
        client_id ||= params[:client_id]
        client_secret ||= params[:client_secret]

        return render_token_error("invalid_request", "Missing client credentials") if client_id.blank?

        token_response = ActionMCP::OAuth::Provider.client_credentials_grant(
          client_id: client_id,
          client_secret: client_secret,
          scope: scope
        )

        render json: token_response
      end

      def extract_client_credentials
        auth_header = request.headers["Authorization"]
        if auth_header&.start_with?("Basic ")
          encoded = auth_header.split(" ", 2).last
          decoded = Base64.decode64(encoded)
          decoded.split(":", 2)
        else
          [ nil, nil ]
        end
      end

      def auto_approve_client?(client_id)
        # In development/testing, auto-approve known clients
        # In production, this should check a proper client registry
        Rails.env.development? || Rails.env.test? || oauth_config["auto_approve_clients"]&.include?(client_id)
      end

      def current_user
        # This should be implemented by the application
        # For now, return a default user for development
        if Rails.env.development? || Rails.env.test?
          OpenStruct.new(id: "dev_user", email: "dev@example.com")
        else
          # In production, this should integrate with your authentication system
          nil
        end
      end

      def default_scope
        oauth_config["default_scope"] || "mcp:tools mcp:resources mcp:prompts"
      end

      def render_error(error_code, description)
        render json: {
          error: error_code,
          error_description: description
        }, status: :bad_request
      end

      def render_token_error(error_code, description)
        render json: {
          error: error_code,
          error_description: description
        }, status: :bad_request
      end

      def render_introspection_error
        render json: { active: false }, status: :bad_request
      end

      def render_consent_page(_client_id, _redirect_uri, _scope, _state, _code_challenge, _code_challenge_method)
        # In production, this would render a proper consent page
        # For now, just auto-deny unknown clients
        render json: {
          error: "access_denied",
          error_description: "User denied authorization"
        }, status: :forbidden
      end
    end
  end
end
