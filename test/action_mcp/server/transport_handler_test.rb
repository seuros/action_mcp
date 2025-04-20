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
    end
  end
end
