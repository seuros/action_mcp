# frozen_string_literal: true

module ActionMCP
  class OAuthIdentifier < GatewayIdentifier
    identifier :user
    authenticates :oauth

    def resolve
      info = @request.env["action_mcp.oauth_token_info"] or
        raise Unauthorized, "Missing OAuth info"

      uid = info["user_id"] || info["sub"] || info[:user_id]
      raise Unauthorized, "Invalid OAuth info" unless uid

      # Try to find existing user or create one for demo purposes
      user = User.find_by(email: uid) ||
             User.find_by(email: "#{uid}@example.com") ||
             create_oauth_user(uid)

      user || raise(Unauthorized, "Unable to resolve OAuth user")
    end

    private

    def create_oauth_user(uid)
      return nil unless defined?(User)

      email = uid.include?("@") ? uid : "#{uid}@example.com"
      User.create!(email: email)
    rescue ActiveRecord::RecordInvalid
      nil
    end
  end
end
