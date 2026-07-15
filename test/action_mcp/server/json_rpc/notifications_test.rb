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

        test "notifications bypass request-only common methods" do
          result = @handler.send(:handle_common_methods, "notifications/cancelled", nil,
                                 { "requestId" => "req-123", "reason" => "Test cancelled" })
          assert_nil result
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

        test "roots list changed requests a fresh list when negotiated" do
          @session.define_singleton_method(:client_capabilities) do
            { "roots" => { "listChanged" => true } }
          end
          notification = JSON_RPC::Notification.new(
            method: "notifications/roots/list_changed"
          )

          assert_nil @handler.call(notification)

          request = @session.written
          assert_instance_of JSON_RPC::Request, request
          assert_equal "roots/list", request.method
        end

        test "roots list changed is ignored without listChanged negotiation" do
          @session.define_singleton_method(:client_capabilities) do
            { "roots" => {} }
          end
          notification = JSON_RPC::Notification.new(
            method: "notifications/roots/list_changed"
          )

          assert_nil @handler.call(notification)
          assert_nil @session.written
        end
      end
    end
  end
end
