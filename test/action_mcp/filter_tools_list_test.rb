# frozen_string_literal: true

require "test_helper"

class FilterToolsListTest < ActiveSupport::TestCase
  setup do
    session_store = ActionMCP::Server.session_store
    @session = session_store.create_session(nil, {
      initialized: false,
      protocol_version: ActionMCP::DEFAULT_PROTOCOL_VERSION
    })
    @session.tool_registry = [ "calculate_sum" ]
    session_store.save_session(@session)
    @transport = ActionMCP::Server::TransportHandler.new(@session, messaging_mode: :return)
  end

  test "returns all tools when session does not respond to filter_tools_list" do
    refute @session.respond_to?(:filter_tools_list)

    @transport.send_tools_list("test-1")
    response = @transport.get_last_response

    assert_equal 1, response.result[:tools].length
  end

  test "calls filter_tools_list when session responds to it" do
    filter_called = false
    @session.define_singleton_method(:filter_tools_list) do |tools, _params|
      filter_called = true
      tools
    end

    @transport.send_tools_list("test-2")

    assert filter_called
  end

  test "uses filter return value as the tools list" do
    @session.define_singleton_method(:filter_tools_list) do |_tools, _params|
      []
    end

    @transport.send_tools_list("test-3")
    response = @transport.get_last_response

    assert_equal [], response.result[:tools]
  end

  test "passes registered tools and params to filter" do
    received_tools = nil
    received_params = nil

    @session.define_singleton_method(:filter_tools_list) do |tools, params|
      received_tools = tools
      received_params = params
      tools
    end

    test_params = { "cursor" => "abc" }
    @transport.send_tools_list("test-4", test_params)

    assert_kind_of Array, received_tools
    assert_equal 1, received_tools.length
    assert_equal test_params, received_params
  end

  test "falls back to unfiltered tools when filter raises" do
    @session.define_singleton_method(:filter_tools_list) do |_tools, _params|
      raise StandardError, "filter exploded"
    end

    @transport.send_tools_list("test-5")
    response = @transport.get_last_response

    assert_equal 1, response.result[:tools].length
  end

  test "falls back to unfiltered tools when filter returns nil" do
    @session.define_singleton_method(:filter_tools_list) do |_tools, _params|
      nil
    end

    @transport.send_tools_list("test-6")
    response = @transport.get_last_response

    assert_equal 1, response.result[:tools].length
  end

  test "falls back to unfiltered tools when filter returns non-array" do
    @session.define_singleton_method(:filter_tools_list) do |_tools, _params|
      "not an array"
    end

    @transport.send_tools_list("test-7")
    response = @transport.get_last_response

    assert_equal 1, response.result[:tools].length
  end

  test "strips nil entries from filtered array" do
    @session.define_singleton_method(:filter_tools_list) do |tools, _params|
      [ nil ] + tools
    end

    @transport.send_tools_list("test-8")
    response = @transport.get_last_response

    assert_equal 1, response.result[:tools].length
  end

  test "strips non-tool entries from filtered array" do
    @session.define_singleton_method(:filter_tools_list) do |tools, _params|
      [ "CalculateSum", 42 ] + tools
    end

    @transport.send_tools_list("test-9")
    response = @transport.get_last_response

    assert_equal 1, response.result[:tools].length
  end
end
