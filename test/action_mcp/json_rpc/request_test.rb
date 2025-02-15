# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module JsonRpc
    class RequestTest < ActiveSupport::TestCase
      test "request serializes correctly" do
        request = Request.new(id: 1, method: "testMethod", params: { key: "value" })
        expected_hash = { jsonrpc: "2.0", id: 1, method: "testMethod", params: { key: "value" } }
        assert_equal expected_hash, request.to_h
      end
    end
  end
end
