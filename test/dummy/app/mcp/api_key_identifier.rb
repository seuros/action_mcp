# frozen_string_literal: true

# API key authentication identifier for API clients
# Authenticates users via X-API-Key header
class ApiKeyIdentifier < ActionMCP::GatewayIdentifier
  identifier :user
  authenticates :api_key

  def resolve
    api_key = @request.headers["X-API-Key"]
    raise Unauthorized, "API key required" unless api_key.present?

    user = User.active.find_by(api_key: api_key)
    raise Unauthorized, "Invalid API key" unless user

    # Update last login timestamp for API usage tracking
    user.touch_last_login!

    user
  rescue ActiveRecord::RecordNotFound
    raise Unauthorized, "User not found"
  end
end
