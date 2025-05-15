# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    module JsonRpc
      class NotificationsTest < ActiveSupport::TestCase
        include TransportMocks

        setup do
          @session = DummySession.new
          # Add a read method that accepts an argument
          def @session.read(request = nil)
            # Do nothing with the request in the test
          end
          @transport = TransportHandler.new(@session)
          @handler = JsonRpcHandler.new(@transport)
        end

        test "notifications are processed properly" do
          # Create a JSON-RPC notification
          notification = JSON_RPC::Notification.new(
            method: "notifications/cancelled",
            params: { "requestId" => "req-123", "reason" => "User cancelled" }
          )

          # Process the notification
          assert_nil @handler.call(notification)
        end

        test "notification method returns true from handle_common_methods" do
          result = @handler.send(:handle_common_methods, "notifications/cancelled", nil,
                                 { "requestId" => "req-123", "reason" => "Test cancelled" })
          assert_equal true, result, "handle_common_methods should return true for notifications"
        end

        test "unknown notifications are processed without errors" do
          # Create a JSON-RPC notification with an unknown method
          notification = JSON_RPC::Notification.new(
            method: "notifications/unknown_type",
            params: { "data" => "test" }
          )

          # Process the notification
          assert_nil @handler.call(notification)
        end
      end
    end
  end
end
