# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module JsonRpc
    class ResponseTest < ActiveSupport::TestCase
      test "response with result serializes correctly" do
        response = Response.new(id: 1, result: "success")
        expected_hash = { jsonrpc: "2.0", id: 1, result: "success" }
        assert_equal expected_hash, response.to_h
      end

      test "response with error serializes correctly" do
        response = Response.new(id: 1, error: { code: -32_603, message: "Internal error" })
        expected_hash = {
          jsonrpc: "2.0",
          id: 1,
          error: { code: -32_603, message: "Internal error" }
        }
        assert_equal expected_hash, response.to_h
      end

      test "response validation rejects both result and error" do
        assert_raises(ArgumentError) { Response.new(id: 1, result: "ok", error: { code: -32_603, message: "error" }) }
      end

      test "response validation rejects neither result nor error" do
        assert_raises(ArgumentError) { Response.new(id: 1) }
      end
    end
  end
end
