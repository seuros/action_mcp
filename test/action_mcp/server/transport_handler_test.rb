# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class TransportHandlerTest < ActiveSupport::TestCase
      # Minimal session stub – just captures whatever gets written.
      class DummySession
        attr_reader :written

        def write(data) = @written = data
        def read        = nil
        def initialize! = true
        def initialized? = true
      end

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
