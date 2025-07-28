# frozen_string_literal: true

module ActionMCP
  module GatewayIdentifiers
    # Example Gateway identifier for API key-based authentication.
    #
    # This identifier looks for API keys in various locations:
    # - Authorization header (Bearer token)
    # - Custom X-API-Key header
    # - Query parameters
    #
    # @example Usage in ApplicationGateway
    #   class ApplicationGateway < ActionMCP::Gateway
    #     identified_by ActionMCP::GatewayIdentifiers::ApiKeyIdentifier
    #   end
    #
    # @example Configuration
    #   # config/mcp.yml
    #   authentication_methods: ["api_key"]
    #
    # @example API Key usage
    #   # Via Authorization header:
    #   # Authorization: Bearer your-api-key-here
    #   #
    #   # Via custom header:
    #   # X-API-Key: your-api-key-here
    #   #
    #   # Via query parameter:
    #   # ?api_key=your-api-key-here
    class ApiKeyIdentifier < ActionMCP::GatewayIdentifier
      identifier :user
      authenticates :api_key

      def resolve
        api_key = extract_api_key
        raise Unauthorized, "Missing API key" unless api_key

        # Look up user by API key
        # Assumes you have an api_key or api_token field on your User model
        user = User.find_by(api_key: api_key) || User.find_by(api_token: api_key)
        raise Unauthorized, "Invalid API key" unless user

        # Optional: Check if API key is still valid (not expired, user active, etc.)
        if user.respond_to?(:api_key_expired?) && user.api_key_expired?
          raise Unauthorized, "API key expired"
        end

        if user.respond_to?(:active?) && !user.active?
          raise Unauthorized, "User account inactive"
        end

        user
      end
    end
  end
end
