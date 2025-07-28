# frozen_string_literal: true

module ActionMCP
  # Example Gateway identifiers for common authentication patterns.
  #
  # These identifiers provide ready-to-use implementations for popular
  # Rails authentication patterns. You can use them directly or as
  # templates for your own custom identifiers.
  #
  # @example Using in ApplicationGateway
  #   class ApplicationGateway < ActionMCP::Gateway
  #     # Use multiple identifiers (tried in order)
  #     identified_by ActionMCP::GatewayIdentifiers::WardenIdentifier,
  #                   ActionMCP::GatewayIdentifiers::ApiKeyIdentifier
  #   end
  #
  # @example Configuration
  #   # config/mcp.yml
  #   authentication_methods: ["warden", "api_key"]
  module GatewayIdentifiers
    autoload :WardenIdentifier, "action_mcp/gateway_identifiers/warden_identifier"
    autoload :DeviseIdentifier, "action_mcp/gateway_identifiers/devise_identifier"
    autoload :RequestEnvIdentifier, "action_mcp/gateway_identifiers/request_env_identifier"
    autoload :ApiKeyIdentifier, "action_mcp/gateway_identifiers/api_key_identifier"
  end
end
