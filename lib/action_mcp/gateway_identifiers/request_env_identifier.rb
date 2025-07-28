# frozen_string_literal: true

module ActionMCP
  module GatewayIdentifiers
    # Example Gateway identifier for custom request environment-based authentication.
    #
    # This identifier looks for user information in custom request headers or environment
    # variables. Useful for authentication set up by upstream proxies, API gateways,
    # or custom middleware.
    #
    # @example Usage in ApplicationGateway
    #   class ApplicationGateway < ActionMCP::Gateway
    #     identified_by ActionMCP::GatewayIdentifiers::RequestEnvIdentifier
    #   end
    #
    # @example Configuration
    #   # config/mcp.yml
    #   authentication_methods: ["request_env"]
    #
    # @example Nginx/Proxy setup
    #   # Your proxy/gateway might set headers like:
    #   # X-User-ID: 123
    #   # X-User-Email: user@example.com
    #   # X-User-Roles: admin,user
    class RequestEnvIdentifier < ActionMCP::GatewayIdentifier
      identifier :user
      authenticates :request_env

      def resolve
        user_id = @request.env["HTTP_X_USER_ID"]
        raise Unauthorized, "User ID header missing" unless user_id

        # You might also want to get additional user info from headers
        email = @request.env["HTTP_X_USER_EMAIL"]
        roles = @request.env["HTTP_X_USER_ROLES"]&.split(",") || []

        # Option 1: Find user in database
        begin
          user = User.find(user_id)
          # Optional: verify email matches if provided
          if email && user.email != email
            raise Unauthorized, "User email mismatch"
          end
          user
        rescue ActiveRecord::RecordNotFound
          raise Unauthorized, "Invalid user"
        end

        # Option 2: Create a simple user object from headers (if you don't want DB lookup)
        # OpenStruct.new(
        #   id: user_id,
        #   email: email,
        #   roles: roles
        # )
      end
    end
  end
end
