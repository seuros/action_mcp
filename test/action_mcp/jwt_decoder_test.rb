# frozen_string_literal: true

# test/lib/action_mcp/jwt_decoder_test.rb
require "test_helper"

module ActionMCP
  class JwtDecoderTest < ActiveSupport::TestCase
    test "decodes valid JWT" do
      token = JWT.encode({ user_id: 42 }, ActionMCP::JwtDecoder.secret, ActionMCP::JwtDecoder.algorithm)
      payload = ActionMCP::JwtDecoder.decode(token)
      assert_equal 42, payload["user_id"]
    end

    test "raises on invalid token" do
      assert_raises(ActionMCP::JwtDecoder::DecodeError) do
        ActionMCP::JwtDecoder.decode("not.a.jwt")
      end
    end
  end
end
