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
          result = @handler.call(notification)

          # Verify the result type
          assert_equal :notifications_only, result[:type]
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
          result = @handler.call(notification)

          # Should still return notifications_only without error
          assert_equal :notifications_only, result[:type]
        end

        test "error in notification handling doesn't propagate" do
          # Create a buggy session that will cause an error during process_notifications
          buggy_session = DummySession.new
          # Add a read method that doesn't raise errors
          def buggy_session.read(request = nil)
            # Do nothing with the request
          end
          buggy_transport = TransportHandler.new(buggy_session)
          buggy_handler = JsonRpcHandler.new(buggy_transport)

          # Make the process_notifications method raise an error
          def buggy_handler.process_notifications(method_name, params)
            raise "Simulated error in notification processing"
          end

          # Create a notification
          notification = JSON_RPC::Notification.new(
            method: "notifications/test",
            params: {}
          )

          # This should not raise an error
          result = nil
          assert_nothing_raised do
            result = buggy_handler.call(notification)
          end

          # Should still return notifications_only
          assert_equal :notifications_only, result[:type]
        end
      end
    end
  end
end
