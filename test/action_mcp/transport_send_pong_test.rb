# frozen_string_literal: true

require "test_helper"

class TransportSendPongTest < ActiveSupport::TestCase
  include TransportMocks

  test "send_pong returns empty result response for given id" do
    session  = DummySession.new
    handler  = ActionMCP::Server::TransportHandler.new(session)

    handler.send_pong("42")

    resp = session.written
    assert_instance_of JSON_RPC::Response, resp
    assert_equal "42", resp.id
    assert_equal({}, resp.result)
    assert_nil resp.error
  end
end
