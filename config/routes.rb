# frozen_string_literal: true

ActionMCP::Engine.routes.draw do
  get "/up", to: "/rails/health#show", as: :action_mcp_health_check

  # MCP 2025-03-26 Spec routes
  get "/", to: "application#show", as: :mcp_get
  post "/", to: "application#create", as: :mcp_post
  delete "/", to: "application#destroy", as: :mcp_delete
end
