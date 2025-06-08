# frozen_string_literal: true

Rails.application.routes.draw do
  mount ActionMCP::Engine, at: "/"
  get "/gateway_up", to: "mcp_gateway_test#up"
end
