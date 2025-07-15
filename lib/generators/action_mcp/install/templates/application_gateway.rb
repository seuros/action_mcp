# frozen_string_literal: true

class ApplicationGateway < ActionMCP::Gateway
  # Specify what attributes identify a connection
  # Multiple identifiers can be used (e.g., user, account, organization)
  identified_by :user

  protected

  # Override this method to implement your authentication logic
  # Must return a hash with keys matching the identified_by attributes
  # or raise ActionMCP::UnauthorizedError
  def authenticate!
    # Example using JWT:
    token = extract_bearer_token
    raise ActionMCP::UnauthorizedError, "Missing token" unless token

    payload = ActionMCP::JwtDecoder.decode(token)
    user = resolve_user(payload)

    raise ActionMCP::UnauthorizedError, "Unauthorized" unless user

    # Return a hash with all identified_by attributes
    { user: user }
  rescue ActionMCP::JwtDecoder::DecodeError => e
    raise ActionMCP::UnauthorizedError, e.message
  end

  private

  # Example method to resolve user from JWT payload
  def resolve_user(payload)
    return nil unless payload.is_a?(Hash)

    user_id = payload["user_id"] || payload["sub"]
    return nil unless user_id

    # Replace with your User model lookup
    User.find_by(id: user_id)
  end
end
