# frozen_string_literal: true

# Bearer token authentication identifier for modern API clients
# Authenticates users via Authorization: Bearer header
class BearerTokenIdentifier < ActionMCP::GatewayIdentifier
  identifier :user
  authenticates :bearer_token

  def resolve
    auth_header = @request.headers["Authorization"]
    raise Unauthorized, "Authorization header required" unless auth_header.present?

    # Extract bearer token
    token = auth_header.match(/\ABearer (.+)\z/)&.captures&.first
    raise Unauthorized, "Bearer token required" unless token.present?

    # In this example, we're using the API key as the bearer token
    # In production, you might use dedicated bearer tokens or other token systems
    user = User.active.find_by(api_key: token)
    raise Unauthorized, "Invalid bearer token" unless user

    user.touch_last_login!

    user
  rescue ActiveRecord::RecordNotFound
    raise Unauthorized, "User not found"
  end
end
