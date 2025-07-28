# frozen_string_literal: true

# Session-based authentication controller for web applications
class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create, :destroy ]

  # <rails-lens:routes:begin>
  # ROUTE: /login, name: login, via: GET
  # <rails-lens:routes:end>
  def new
    # Login form (in a real app you'd have a view)
    render json: {
      message: "Login form",
      instructions: "POST to /sessions with email and password"
    }
  end

  # <rails-lens:routes:begin>
  # ROUTE: /sessions, name: sessions, via: POST
  # <rails-lens:routes:end>
  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password]) && user.active?
      session[:user_id] = user.id
      user.touch_last_login!

      render json: {
        message: "Logged in successfully",
        user: { id: user.id, email: user.email, name: user.name }
      }
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  # <rails-lens:routes:begin>
  # ROUTE: /sessions, name: sessions, via: DELETE
  # <rails-lens:routes:end>
  def destroy
    session[:user_id] = nil
    render json: { message: "Logged out successfully" }
  end

  # <rails-lens:routes:begin>
  # ROUTE: /sessions, name: sessions, via: GET
  # <rails-lens:routes:end>
  def show
    if current_user
      render json: {
        user: {
          id: current_user.id,
          email: current_user.email,
          name: current_user.name,
          last_login_at: current_user.last_login_at
        }
      }
    else
      render json: { error: "Not logged in" }, status: :unauthorized
    end
  end
end
