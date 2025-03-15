# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module JsonRpc
    class JsonRpcErrorTest < ActiveSupport::TestCase
      test "error codes are correctly retrieved" do
        error = JsonRpcError[:invalid_request]
        assert_equal(-32_600, error[:code])
        assert_equal "Invalid request", error[:message]
      end

      test "build custom error" do
        error = JsonRpcError.build(:method_not_found, message: "Custom message", data: { detail: "Extra info" })
        assert_equal(-32_601, error[:code])
        assert_equal "Custom message", error[:message]
        assert_equal({ detail: "Extra info" }, error[:data])
      end

      test "error instance returns correct json structure" do
        error = JsonRpcError.new(:invalid_params, data: { param: "id" })
        json_error = error.to_h
        assert_equal(-32_602, json_error[:code])
        assert_equal "Invalid params", json_error[:message]
        assert_equal({ param: "id" }, json_error[:data])
      end
    end
  end
end
