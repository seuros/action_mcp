# frozen_string_literal: true

ActionMCP::Engine.routes.draw do
  get "/up", to: "/rails/health#show", as: :action_mcp_health_check

  # OAuth 2.1 metadata endpoints
  get "/.well-known/oauth-authorization-server", to: "oauth/metadata#authorization_server", as: :oauth_authorization_server_metadata
  get "/.well-known/oauth-protected-resource", to: "oauth/metadata#protected_resource", as: :oauth_protected_resource_metadata

  # OAuth 2.1 endpoints
  get "/oauth/authorize", to: "oauth/endpoints#authorize", as: :oauth_authorize
  post "/oauth/token", to: "oauth/endpoints#token", as: :oauth_token
  post "/oauth/introspect", to: "oauth/endpoints#introspect", as: :oauth_introspect
  post "/oauth/revoke", to: "oauth/endpoints#revoke", as: :oauth_revoke
  post "/oauth/register", to: "oauth/registration#create", as: :oauth_register

  # MCP 2025-03-26 Spec routes
  get "/", to: "application#show", as: :mcp_get
  post "/", to: "application#create", as: :mcp_post
  delete "/", to: "application#destroy", as: :mcp_delete
end
