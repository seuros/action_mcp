# lib/action_mcp/jwt_decoder.rb
require "jwt"

module ActionMCP
  class JwtDecoder
    class DecodeError < StandardError; end

    # Configurable defaults
    class << self
      attr_accessor :secret, :algorithm

      def decode(token)
        payload, _header = JWT.decode(token, secret, true, { algorithm: algorithm })
        payload
      rescue JWT::ExpiredSignature
        raise DecodeError, "Token has expired"
      rescue JWT::DecodeError => e
        raise DecodeError, e.message
      end
    end

    # Defaults (can be overridden in an initializer)
    self.secret = ENV.fetch("ACTION_MCP_JWT_SECRET") { "change-me" }
    self.algorithm = "HS256"
  end
end
