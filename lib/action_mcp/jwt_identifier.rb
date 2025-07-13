# frozen_string_literal: true

module ActionMCP
  class JwtIdentifier < GatewayIdentifier
    identifier :user
    authenticates :jwt

    def resolve
      token = extract_bearer_token
      raise Unauthorized, "Missing JWT" unless token

      payload = ActionMCP::JwtDecoder.decode(token)
      user = User.find_by(id: payload["sub"] || payload["user_id"])
      return user if user

      raise Unauthorized, "Invalid JWT user"
    rescue ActionMCP::JwtDecoder::DecodeError => e
      raise Unauthorized, "Invalid JWT token: #{e.message}"
    end

    private

    def extract_bearer_token
      header = @request.env["HTTP_AUTHORIZATION"] || ""
      header[/\ABearer (.+)\z/, 1]
    end
  end
end
