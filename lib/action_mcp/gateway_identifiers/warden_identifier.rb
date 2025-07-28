# frozen_string_literal: true

module ActionMCP
  module GatewayIdentifiers
    # Example Gateway identifier for Warden-based authentication.
    #
    # This identifier works with Warden middleware which is commonly used by Devise.
    # Warden sets the authenticated user in request.env['warden.user'] after successful authentication.
    #
    # @example Usage in ApplicationGateway
    #   class ApplicationGateway < ActionMCP::Gateway
    #     identified_by ActionMCP::GatewayIdentifiers::WardenIdentifier
    #   end
    #
    # @example Configuration
    #   # config/mcp.yml
    #   authentication_methods: ["warden"]
    #
    # @example With Devise
    #   # In your controller or middleware, ensure Warden is configured:
    #   # devise_for :users
    #   # authenticate_user! # This sets up Warden env
    class WardenIdentifier < ActionMCP::GatewayIdentifier
      identifier :user
      authenticates :warden

      def resolve
        warden = @request.env["warden"]
        raise Unauthorized, "Warden not available" unless warden

        user = warden.user
        raise Unauthorized, "Not authenticated" unless user

        user
      end
    end
  end
end
