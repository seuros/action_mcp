# frozen_string_literal: true

Rails.application.routes.draw do
  get "/gateway_up", to: "mcp_gateway_test#up"
end
