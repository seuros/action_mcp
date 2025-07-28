# frozen_string_literal: true

# Session-based authentication identifier for web applications
# Authenticates users via Rails sessions (cookies)
class SessionIdentifier < ActionMCP::GatewayIdentifier
  identifier :user
  authenticates :session

  def resolve
    user_id = @request.session[:user_id]
    raise Unauthorized, "Not logged in" unless user_id

    user = User.active.find_by(id: user_id)
    raise Unauthorized, "Invalid user" unless user

    # Update last login timestamp
    user.touch_last_login!

    user
  rescue ActiveRecord::RecordNotFound
    raise Unauthorized, "User not found"
  end
end
