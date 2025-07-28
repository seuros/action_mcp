# frozen_string_literal: true

Rails.application.routes.draw do
  mount ActionMCP::Engine, at: "/"

  # Gateway test endpoint
  get "/gateway_up", to: "mcp_gateway_test#up"

  # Authentication routes for demonstrating Gateway patterns

  # Session-based authentication
  get "/login", to: "sessions#new"
  post "/sessions", to: "sessions#create"
  delete "/sessions", to: "sessions#destroy"
  get "/sessions", to: "sessions#show"

  # User management
  resources :users, only: [ :create, :show ] do
    member do
      patch :api_key # Regenerate API key
    end
  end

  # Convenience routes for testing
  get "/", to: proc { [ 200, {}, [ "ActionMCP Dummy App - Gateway Authentication Demo" ] ] }
end
