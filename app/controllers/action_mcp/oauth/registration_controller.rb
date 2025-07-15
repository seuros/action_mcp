# frozen_string_literal: true

module ActionMCP
  module OAuth
    # OAuth 2.0 Dynamic Client Registration Controller (RFC 7591)
    # Allows clients to dynamically register with the authorization server
    class RegistrationController < ActionController::Base
      protect_from_forgery with: :null_session
      before_action :check_oauth_enabled
      before_action :check_registration_enabled

      # POST /oauth/register
      # Dynamic client registration endpoint as per RFC 7591
      def create
        # Parse client metadata from request body
        client_metadata = parse_client_metadata

        # Validate required fields
        validate_client_metadata(client_metadata)

        # Generate client credentials
        client_id = generate_client_id
        client_secret = nil # Public clients by default

        # Generate client secret for confidential clients
        client_secret = generate_client_secret if client_metadata["token_endpoint_auth_method"] != "none"

        # Store client registration
        client_info = {
          client_id: client_id,
          client_secret: client_secret,
          client_id_issued_at: Time.current.to_i,
          client_metadata: client_metadata,
          created_at: Time.current
        }

        # Save client registration (delegated to provider)
        ActionMCP::OAuth::Provider.register_client(client_info)

        # Build response according to RFC 7591
        response_data = {
          client_id: client_id,
          client_id_issued_at: client_info[:client_id_issued_at]
        }

        # Include client secret for confidential clients
        if client_secret
          response_data[:client_secret] = client_secret
          response_data[:client_secret_expires_at] = 0 # Never expires
        end

        # Include all client metadata in response
        response_data.merge!(client_metadata)

        # Add registration management fields if enabled
        if oauth_config[:enable_registration_management]
          response_data[:registration_access_token] = generate_registration_access_token(client_id)
          response_data[:registration_client_uri] = registration_client_url(client_id)
        end

        render json: response_data, status: :created
      rescue ActionMCP::OAuth::Error => e
        render_registration_error(e.oauth_error_code, e.message)
      rescue StandardError => e
        Rails.logger.error "Registration error: #{e.message}"
        render_registration_error("invalid_client_metadata", "Invalid client metadata")
      end

      private

      def check_oauth_enabled
        auth_methods = ActionMCP.configuration.authentication_methods
        return if auth_methods&.include?("oauth")

        head :not_found
      end

      def check_registration_enabled
        return if oauth_config[:enable_dynamic_registration]

        head :not_found
      end

      def oauth_config
        @oauth_config ||= HashWithIndifferentAccess.new(ActionMCP.configuration.oauth_config || {})
      end

      def parse_client_metadata
        # RFC 7591 requires JSON request body
        unless request.content_type&.include?("application/json")
          raise ActionMCP::OAuth::InvalidRequestError, "Content-Type must be application/json"
        end

        JSON.parse(request.body.read)
      rescue JSON::ParserError
        raise ActionMCP::OAuth::InvalidRequestError, "Invalid JSON"
      end

      def validate_client_metadata(metadata)
        # Validate redirect URIs (required for authorization code flow)
        if metadata["grant_types"]&.include?("authorization_code") ||
           metadata["response_types"]&.include?("code")
          unless metadata["redirect_uris"].is_a?(Array) && metadata["redirect_uris"].any?
            raise ActionMCP::OAuth::InvalidClientMetadataError, "redirect_uris required for authorization code flow"
          end

          # Validate redirect URI format
          metadata["redirect_uris"].each do |uri|
            validate_redirect_uri(uri)
          end
        end

        # Validate grant types
        if metadata["grant_types"]
          unsupported = metadata["grant_types"] - supported_grant_types
          if unsupported.any?
            raise ActionMCP::OAuth::InvalidClientMetadataError, "Unsupported grant types: #{unsupported.join(', ')}"
          end
        end

        # Validate response types
        if metadata["response_types"]
          unsupported = metadata["response_types"] - supported_response_types
          if unsupported.any?
            raise ActionMCP::OAuth::InvalidClientMetadataError, "Unsupported response types: #{unsupported.join(', ')}"
          end
        end

        # Validate token endpoint auth method
        return unless metadata["token_endpoint_auth_method"]
        return if supported_auth_methods.include?(metadata["token_endpoint_auth_method"])

        raise ActionMCP::OAuth::InvalidClientMetadataError, "Unsupported token endpoint auth method"
      end

      def validate_redirect_uri(uri)
        parsed = URI.parse(uri)

        # Must be absolute URI
        raise ActionMCP::OAuth::InvalidClientMetadataError, "Redirect URI must be absolute" unless parsed.absolute?

        # For non-localhost, must use HTTPS
        unless [ "localhost", "127.0.0.1" ].include?(parsed.host) || parsed.scheme == "https"
          raise ActionMCP::OAuth::InvalidClientMetadataError, "Redirect URI must use HTTPS"
        end
      rescue URI::InvalidURIError
        raise ActionMCP::OAuth::InvalidClientMetadataError, "Invalid redirect URI format"
      end

      def generate_client_id
        # Generate a unique client identifier
        "mcp_#{SecureRandom.hex(16)}"
      end

      def generate_client_secret
        # Generate a secure client secret
        SecureRandom.urlsafe_base64(32)
      end

      def generate_registration_access_token(_client_id)
        # Generate a token for managing this registration
        SecureRandom.urlsafe_base64(32)
      end

      def registration_client_url(client_id)
        "#{request.base_url}/oauth/register/#{client_id}"
      end

      def supported_grant_types
        grants = [ "authorization_code" ]
        grants << "refresh_token" if oauth_config[:enable_refresh_tokens]
        grants << "client_credentials" if oauth_config[:enable_client_credentials]
        grants
      end

      def supported_response_types
        [ "code" ]
      end

      def supported_auth_methods
        methods = %w[client_secret_basic client_secret_post]
        methods << "none" if oauth_config.fetch(:allow_public_clients, true)
        methods
      end

      def render_registration_error(error_code, description)
        render json: {
          error: error_code,
          error_description: description
        }, status: :bad_request
      end
    end

    # Custom error for invalid client metadata
    class InvalidClientMetadataError < Error
      def initialize(message = "Invalid client metadata")
        super(message, "invalid_client_metadata")
      end
    end
  end
end
