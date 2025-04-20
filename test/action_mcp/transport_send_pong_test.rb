# frozen_string_literal: true

require "test_helper"
require "json"

class DummySession
  attr_reader :written

  def write(data) = @written = data
  def read        = nil
  def initialize! = true
  def initialized? = true
end

class TransportSendPongTest < ActiveSupport::TestCase
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
