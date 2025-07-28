# frozen_string_literal: true

class ApplicationController < ActionController::Base
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

  helper_method :current_user, :user_signed_in?
end
