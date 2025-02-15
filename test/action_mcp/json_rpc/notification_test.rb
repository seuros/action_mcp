# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module JsonRpc
    class NotificationTest < ActiveSupport::TestCase
      test "notification serializes correctly" do
        notification = Notification.new(method: "testMethod", params: [ 1, 2, 3 ])
        expected_hash = { jsonrpc: "2.0", method: "testMethod", params: [ 1, 2, 3 ] }
        assert_equal expected_hash, notification.to_h
      end
    end
  end
end
