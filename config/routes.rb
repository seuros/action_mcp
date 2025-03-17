# frozen_string_literal: true

ActionMCP::Engine.routes.draw do
  get "/", to: "sse#events", as: :sse_out
  post "/", to: "messages#create", as: :sse_in
end
