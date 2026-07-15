# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class TransportHandlerTest < ActiveSupport::TestCase
      include TransportMocks

      test "send_jsonrpc_request builds a valid JSON‑RPC request object" do
        session  = DummySession.new
        handler  = ActionMCP::Server::TransportHandler.new(session)

        handler.send_jsonrpc_request("ping")

        req = session.written
        assert_instance_of JSON_RPC::Request, req
        assert_equal "ping", req.method
        assert req.id.present?, "auto‑generated id expected"
        # params default to nil when none supplied
        assert_nil req.params
      end

      test "resource updates are only sent to subscribed sessions" do
        session = DummySession.new
        subscribed = false
        session.define_singleton_method(:resource_subscribed?) { |_uri| subscribed }
        handler = ActionMCP::Server::TransportHandler.new(session)

        assert_nil handler.send_resource_updated_notification("test://resource")
        assert_nil session.written

        subscribed = true
        handler.send_resource_updated_notification("test://resource")

        notification = session.written
        assert_instance_of JSON_RPC::Notification, notification
        assert_equal "notifications/resources/updated", notification.method
        assert_equal({ uri: "test://resource" }, notification.params)
      end
    end
  end
end
