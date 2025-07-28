# frozen_string_literal: true

module ActionMCP
  module GatewayIdentifiers
    # Example Gateway identifier for direct Devise integration.
    #
    # This identifier looks for the user directly in request.env['devise.user'] which
    # may be set by custom Devise middleware or helpers.
    #
    # @example Usage in ApplicationGateway
    #   class ApplicationGateway < ActionMCP::Gateway
    #     identified_by ActionMCP::GatewayIdentifiers::DeviseIdentifier
    #   end
    #
    # @example Configuration
    #   # config/mcp.yml
    #   authentication_methods: ["devise"]
    #
    # @example Custom Devise middleware setup
    #   # In your application, you might set this in a before_action:
    #   # request.env['devise.user'] = current_user if user_signed_in?
    class DeviseIdentifier < ActionMCP::GatewayIdentifier
      identifier :user
      authenticates :devise

      def resolve
        user = @request.env["devise.user"]
        raise Unauthorized, "Not authenticated" unless user

        user
      end
    end
  end
end
