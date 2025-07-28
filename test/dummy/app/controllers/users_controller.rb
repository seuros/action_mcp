# frozen_string_literal: true

# User management controller for demonstration purposes
class UsersController < ApplicationController
  skip_before_action :verify_authenticity_token

  # <rails-lens:routes:begin>
  # ROUTE: /users, name: users, via: POST
  # <rails-lens:routes:end>
  def create
    user = User.new(user_params)

    if user.save
      render json: {
        message: "User created successfully",
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          api_key: user.api_key
        }
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # <rails-lens:routes:begin>
  # ROUTE: /users/:id, name: user, via: GET
  # <rails-lens:routes:end>
  def show
    user = User.find(params[:id])
    render json: {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        active: user.active,
        last_login_at: user.last_login_at
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :not_found
  end

  # <rails-lens:routes:begin>
  # ROUTE: /users/:id/api_key, name: api_key_user, via: PATCH
  # <rails-lens:routes:end>
  def api_key
    user = User.find(params[:id])
    user.regenerate_api_key!

    render json: {
      message: "API key regenerated",
      api_key: user.api_key
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :not_found
  end

  private

  def user_params
    params.require(:user).permit(:email, :name, :password, :password_confirmation)
  end
end
