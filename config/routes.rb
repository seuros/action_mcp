# frozen_string_literal: true

ActionMCP::Engine.routes.draw do
  # --- Routes for 2024-11-05 Spec (HTTP+SSE) ---
  # Kept for backward compatibility
  get "/", to: "sse#events", as: :sse_out
  post "/", to: "messages#create", as: :sse_in, defaults: { format: "json" }

  # --- Routes for 2025-03-26 Spec (Streamable HTTP) ---
  mcp_endpoint = ActionMCP.configuration.mcp_endpoint_path
  get mcp_endpoint, to: "unified#handle_get", as: :mcp_get
  post mcp_endpoint, to: "unified#handle_post", as: :mcp_post
end
