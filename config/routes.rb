# frozen_string_literal: true

ActionMCP::Engine.routes.draw do
  get "#{ActionMCP.configuration.base_path}}/up", to: "/rails/health#show", as: :action_mcp_health_check

  # MCP 2025-03-26 Spec routes
  get ActionMCP.configuration.base_path, to: "application#show", as: :mcp_get
  post ActionMCP.configuration.base_path, to: "application#create", as: :mcp_post
  delete ActionMCP.configuration.base_path, to: "application#destroy", as: :mcp_delete
end
