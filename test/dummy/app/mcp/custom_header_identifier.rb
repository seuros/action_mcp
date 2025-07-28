# frozen_string_literal: true

# Custom header authentication identifier
# Authenticates users via custom X-User-Email header with validation
class CustomHeaderIdentifier < ActionMCP::GatewayIdentifier
  identifier :user
  authenticates :custom_header

  def resolve
    user_email = @request.headers["X-User-Email"]
    auth_token = @request.headers["X-Auth-Token"]

    raise Unauthorized, "User email and auth token required" unless user_email.present? && auth_token.present?

    user = User.active.find_by(email: user_email)
    raise Unauthorized, "Invalid user email" unless user

    # Simple validation - in production you might use HMAC or other cryptographic methods
    expected_token = Digest::SHA256.hexdigest("#{user.email}:#{user.api_key}")
    raise Unauthorized, "Invalid auth token" unless auth_token == expected_token

    user.touch_last_login!

    user
  rescue ActiveRecord::RecordNotFound
    raise Unauthorized, "User not found"
  end
end
