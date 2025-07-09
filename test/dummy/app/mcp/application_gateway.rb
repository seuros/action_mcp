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
    # Check authentication methods in order
    ActionMCP.configuration.authentication_methods.each do |method|
      case method
      when "oauth"
        # OAuth middleware sets token info in request environment
        token_info = request.env["action_mcp.oauth_token_info"]
        if token_info
          user = resolve_user_from_oauth(token_info)
          return { user: user } if user
        end
      when "jwt"
        # JWT authentication
        token = extract_bearer_token
        if token
          begin
            payload = ActionMCP::JwtDecoder.decode(token)
            user = resolve_user(payload)
            return { user: user } if user
          rescue ActionMCP::JwtDecoder::DecodeError
            # Continue to next method
          end
        end
      when "none"
        # No authentication required
        return default_identity
      end
    end

    raise ActionMCP::UnauthorizedError, "Unauthorized"
  end

  private

  # Resolve user from OAuth token info
  def resolve_user_from_oauth(token_info)
    return nil unless token_info.is_a?(Hash)

    # OAuth token info includes user_id which should map to actual user
    user_id = token_info[:user_id]
    return nil unless user_id

    # Try to find existing user by email (assuming user_id is email or username)
    user = User.find_by(email: user_id) || User.find_by(email: "#{user_id}@example.com")

    # If no user found, create one based on user_id
    unless user
      email = user_id.include?("@") ? user_id : "#{user_id}@example.com"
      user = User.create!(email: email)
      # User created for OAuth user_id: #{user_id}
    end

    user
  end

  # Example method to resolve user from JWT payload
  def resolve_user(payload)
    return nil unless payload.is_a?(Hash)
    user_id = payload["user_id"] || payload["sub"]
    return nil unless user_id

    # Replace with your User model lookup
    User.find_by(id: user_id)
  end
end
