# frozen_string_literal: true

Rails.application.routes.draw do
  mount ActionMCP::Engine => "/action_mcp"
end
