# frozen_string_literal: true

# JWT token authentication identifier
# Authenticates users via Authorization: Bearer JWT tokens
class JwtIdentifier < ActionMCP::GatewayIdentifier
  identifier :user
  authenticates :jwt

  def resolve
    token = extract_bearer_token
    raise Unauthorized, "JWT token required" unless token.present?

    begin
      # Decode JWT with Rails secret
      payload = JWT.decode(token, jwt_secret, true, { algorithm: "HS256" })[0]

      # Extract user ID from payload
      user_id = payload["user_id"]
      raise Unauthorized, "Invalid JWT payload: missing user_id" unless user_id

      # Find user
      user = User.active.find(user_id)
      raise Unauthorized, "User not found or inactive" unless user

      user.touch_last_login!
      user

    rescue JWT::DecodeError => e
      raise Unauthorized, "Invalid JWT token: #{e.message}"
    rescue JWT::ExpiredSignature
      raise Unauthorized, "JWT token has expired"
    rescue ActiveRecord::RecordNotFound
      raise Unauthorized, "User not found"
    end
  end

  private

  def jwt_secret
    # Use Rails secret key base for JWT signing
    Rails.application.secret_key_base
  end
end
