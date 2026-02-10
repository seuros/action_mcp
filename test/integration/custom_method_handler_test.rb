# frozen_string_literal: true

require "test_helper"

class CustomMethodHandlerTest < ActionDispatch::IntegrationTest
  setup do
    session_store = ActionMCP::Server.session_store
    @session = session_store.create_session(nil, {
      initialized: false,
      protocol_version: ActionMCP::DEFAULT_PROTOCOL_VERSION
    })
    @session_id = @session.id
    session_store.save_session(@session)
  end

  teardown do
    ActionMCP.configuration.custom_method_handler = nil
  end

  test "unknown method returns method_not_found when no handler configured" do
    post "/", params: {
      jsonrpc: "2.0", id: "test-1",
      method: "vendor/custom/method",
      params: {}
    }.to_json, headers: json_headers

    assert_response :success
    body = response.parsed_body
    assert body["error"]
    assert_equal(-32_601, body["error"]["code"])
    assert_includes body["error"]["message"], "Method not found"
  end

  test "unknown method returns method_not_found when handler returns falsy" do
    ActionMCP.configuration.custom_method_handler = ->(_method, _id, _params, _transport) { false }

    post "/", params: {
      jsonrpc: "2.0", id: "test-2",
      method: "vendor/custom/method",
      params: {}
    }.to_json, headers: json_headers

    assert_response :success
    body = response.parsed_body
    assert body["error"]
    assert_equal(-32_601, body["error"]["code"])
  end

  test "custom handler handles unknown method when returning truthy" do
    ActionMCP.configuration.custom_method_handler = ->(_method, id, _params, transport) {
      transport.send_jsonrpc_response(id, result: { handled: true })
      true
    }

    post "/", params: {
      jsonrpc: "2.0", id: "test-3",
      method: "vendor/custom/method",
      params: { key: "value" }
    }.to_json, headers: json_headers

    assert_response :success
    body = response.parsed_body
    assert body["result"]
    assert_equal true, body["result"]["handled"]
  end

  test "custom handler receives correct arguments" do
    received_args = {}
    ActionMCP.configuration.custom_method_handler = ->(rpc_method, id, params, transport) {
      received_args[:rpc_method] = rpc_method
      received_args[:id] = id
      received_args[:params] = params
      received_args[:transport_class] = transport.class.name
      transport.send_jsonrpc_response(id, result: {})
      true
    }

    post "/", params: {
      jsonrpc: "2.0", id: "arg-test",
      method: "sparrow/toolsets/list",
      params: { scope: "read" }
    }.to_json, headers: json_headers

    assert_response :success
    assert_equal "sparrow/toolsets/list", received_args[:rpc_method]
    assert_equal "arg-test", received_args[:id]
    assert_equal "read", received_args[:params]["scope"]
    assert_equal "ActionMCP::Server::TransportHandler", received_args[:transport_class]
  end

  test "handler exception returns internal_error response" do
    ActionMCP.configuration.custom_method_handler = ->(_method, _id, _params, _transport) {
      raise StandardError, "kaboom"
    }

    post "/", params: {
      jsonrpc: "2.0", id: "err-test",
      method: "vendor/failing",
      params: {}
    }.to_json, headers: json_headers

    assert_response :success
    body = response.parsed_body
    assert body["error"]
    assert_equal(-32_603, body["error"]["code"])
    assert_includes body["error"]["message"], "Custom method handler error"
  end

  test "handler-raised JsonRpcError passes through with its own error code" do
    ActionMCP.configuration.custom_method_handler = ->(_method, _id, _params, _transport) {
      raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "bad params from handler")
    }

    post "/", params: {
      jsonrpc: "2.0", id: "jrpc-err-test",
      method: "vendor/strict",
      params: {}
    }.to_json, headers: json_headers

    assert_response :success
    body = response.parsed_body
    assert body["error"]
    assert_equal(-32_602, body["error"]["code"])
    assert_includes body["error"]["message"], "bad params from handler"
  end

  private

  def json_headers
    {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "Mcp-Session-Id" => @session_id
    }
  end
end
