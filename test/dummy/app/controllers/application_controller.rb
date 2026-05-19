# frozen_string_literal: true

# Set ACTION_MCP_API_ONLY=1 to boot the dummy app's ApplicationController as
# API-only. Used by test/action_mcp/render_ui_api_only_test.rb to verify that
# ActionMCP::MCPAppRenderer renders templates regardless of host view stack.
# Explicit "1" check so accidental values like "0" or "false" don't enable it.
ApplicationControllerParent = ENV["ACTION_MCP_API_ONLY"] == "1" ? ActionController::API : ActionController::Base

class ApplicationController < ApplicationControllerParent
  # Standard authentication helpers for demonstration
  # These work alongside the Gateway authentication system

  protected

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    unless user_signed_in?
      render json: { error: "Authentication required" }, status: :unauthorized
    end
  end

  def require_api_key
    api_key = request.headers["X-API-Key"]
    unless api_key.present? && User.exists?(api_key: api_key, active: true)
      render json: { error: "Valid API key required" }, status: :unauthorized
    end
  end

  helper_method :current_user, :user_signed_in? unless ENV["ACTION_MCP_API_ONLY"] == "1"
end
