# frozen_string_literal: true

module ActionMCP
  class ApplicationController < ActionController::Metal
    abstract!
    ActionController::API.without_modules(:StrongParameters, :ParamsWrapper).each do |left|
      include left
    end
    include Engine.routes.url_helpers

    def session_key
      @session_key = "action_mcp-sessions-#{session_id}"
    end
  end
end
