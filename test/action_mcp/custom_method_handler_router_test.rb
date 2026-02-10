# frozen_string_literal: true

require "test_helper"

class CustomMethodHandlerRouterTest < ActiveSupport::TestCase
  setup do
    session_store = ActionMCP::Server.session_store
    @session = session_store.create_session(nil, {
      initialized: false,
      protocol_version: ActionMCP::DEFAULT_PROTOCOL_VERSION
    })
    session_store.save_session(@session)
    @transport = ActionMCP::Server::TransportHandler.new(@session, messaging_mode: :return)
    @handler = ActionMCP::Server::JsonRpcHandler.new(@transport)
    @router = ActionMCP::Server::Handlers::Router.new(@handler)
  end

  teardown do
    ActionMCP.configuration.custom_method_handler = nil
  end

  test "raises method_not_found for unknown method when no handler configured" do
    error = assert_raises(JSON_RPC::JsonRpcError) do
      @router.route("vendor/custom", "r-1", {})
    end
    assert_includes error.message, "Method not found"
  end

  test "raises method_not_found when handler returns falsy" do
    ActionMCP.configuration.custom_method_handler = ->(_m, _id, _p, _t) { nil }

    assert_raises(JSON_RPC::JsonRpcError) do
      @router.route("vendor/custom", "r-2", {})
    end
  end

  test "handles method when handler returns truthy" do
    ActionMCP.configuration.custom_method_handler = ->(_m, id, _p, transport) {
      transport.send_jsonrpc_response(id, result: { routed: true })
      true
    }

    @router.route("vendor/custom", "r-3", {})
    response = @transport.get_last_response

    assert_equal({ routed: true }, response.result)
  end

  test "handler receives correct arguments via router" do
    received = {}
    ActionMCP.configuration.custom_method_handler = ->(method, id, params, transport) {
      received[:method] = method
      received[:id] = id
      received[:params] = params
      received[:transport] = transport
      true
    }

    @router.route("sparrow/test", "r-4", { "key" => "val" })

    assert_equal "sparrow/test", received[:method]
    assert_equal "r-4", received[:id]
    assert_equal({ "key" => "val" }, received[:params])
    assert_equal @transport, received[:transport]
  end

  test "wraps handler exception as internal_error" do
    ActionMCP.configuration.custom_method_handler = ->(_m, _id, _p, _t) {
      raise StandardError, "handler blew up"
    }

    error = assert_raises(JSON_RPC::JsonRpcError) do
      @router.route("vendor/custom", "r-5", {})
    end
    assert_includes error.message, "Custom method handler error"
  end

  test "passes through JsonRpcError raised by handler" do
    ActionMCP.configuration.custom_method_handler = ->(_m, _id, _p, _t) {
      raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "bad params from handler")
    }

    error = assert_raises(JSON_RPC::JsonRpcError) do
      @router.route("vendor/custom", "r-6", {})
    end
    assert_includes error.message, "bad params from handler"
  end
end
