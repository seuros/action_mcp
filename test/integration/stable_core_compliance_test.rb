# frozen_string_literal: true

require "test_helper"

class StableCoreComplianceTest < ActionDispatch::IntegrationTest
  PROTOCOL_VERSION = "2025-11-25"

  class RejectingGateway < ActionMCP::Gateway
    def call
      raise ActionMCP::UnauthorizedError, "Bearer token required"
    end
  end

  class SessionRejectingGateway < ActionMCP::Gateway
    def call
      self
    end

    def configure_session(_session)
      raise ActionMCP::UnauthorizedError, "Session is not authorized"
    end
  end

  test "unsupported initialize version negotiates the released server version" do
    session_id = initialize_session(protocol_version: "2099-01-01")

    assert_equal PROTOCOL_VERSION, response.parsed_body.dig("result", "protocolVersion")
    session = ActionMCP::Server.session_store.load_session(session_id)
    assert_equal "initializing", session.status
    refute session.initialized?
  end

  test "schema-valid blank initialize versions negotiate the released server version" do
    [ "", "   " ].each do |requested_version|
      session_id = initialize_session(protocol_version: requested_version)

      assert_equal PROTOCOL_VERSION, response.parsed_body.dig("result", "protocolVersion")
      assert_equal PROTOCOL_VERSION, ActionMCP::Server.session_store.load_session(session_id).protocol_version
    end
  end

  test "initialized notification cannot be the first interaction" do
    post_json(jsonrpc: "2.0", method: "notifications/initialized")

    assert_response :bad_request
    assert_nil response.headers["Mcp-Session-Id"]
    assert_equal(-32_600, response.parsed_body.dig("error", "code"))
  end

  test "operation and initialized notification require the initialization handshake" do
    session_id = initialize_session
    session = ActionMCP::Server.session_store.load_session(session_id)

    post_json(
      { jsonrpc: "2.0", id: "early", method: "tools/list" },
      session_id: session_id,
      protocol_version: PROTOCOL_VERSION
    )
    assert_response :bad_request
    refute session.initialized?

    post_json(
      { jsonrpc: "2.0", method: "notifications/initialized" },
      session_id: session_id,
      protocol_version: "1999-01-01"
    )
    assert_response :bad_request
    refute session.initialized?

    complete_initialization(session_id)
    assert_response :accepted
    assert session.initialized?
  end

  test "request named notifications initialized cannot mutate lifecycle state" do
    session_id = initialize_session
    session = ActionMCP::Server.session_store.load_session(session_id)

    post_json(
      { jsonrpc: "2.0", id: "not-a-notification", method: "notifications/initialized" },
      session_id: session_id,
      protocol_version: PROTOCOL_VERSION
    )

    assert_response :bad_request
    assert_equal "not-a-notification", response.parsed_body["id"]
    assert response.parsed_body["error"]
    refute session.initialized?
  end

  test "accepted JSON-RPC responses return 202 with an empty body" do
    session_id = initialize_session
    complete_initialization(session_id)

    post_json(
      { jsonrpc: "2.0", id: "server-request", result: {} },
      session_id: session_id,
      protocol_version: PROTOCOL_VERSION
    )

    assert_response :accepted
    assert_empty response.body
  end

  test "terminated sessions return 404 for subsequent POST and DELETE requests" do
    session_id = initialize_session
    complete_initialization(session_id)

    delete "/", headers: session_headers(session_id)
    assert_response :no_content

    post_json(
      { jsonrpc: "2.0", id: "after-close", method: "tools/list" },
      session_id: session_id,
      protocol_version: PROTOCOL_VERSION
    )
    assert_response :not_found

    delete "/", headers: session_headers(session_id)
    assert_response :not_found
  end

  test "DELETE rejects an unsupported protocol version without closing the session" do
    session_id = initialize_session
    complete_initialization(session_id)
    session = ActionMCP::Server.session_store.load_session(session_id)

    delete "/", headers: session_headers(session_id, protocol_version: "1999-01-01")

    assert_response :bad_request
    refute_equal "closed", session.status
  end

  test "stable JSON-RPC envelope validation rejects malformed messages" do
    post "/", params: '{"jsonrpc":', headers: json_headers
    assert_response :bad_request
    assert_equal(-32_700, response.parsed_body.dig("error", "code"))

    post_json(jsonrpc: "2.0", id: nil, method: "initialize", params: valid_initialize_params)
    assert_response :bad_request
    assert_equal(-32_600, response.parsed_body.dig("error", "code"))

    post_json(jsonrpc: "2.0", id: "array-params", method: "initialize", params: [])
    assert_response :bad_request
    assert_equal(-32_600, response.parsed_body.dig("error", "code"))

    post_json([ { jsonrpc: "2.0", id: "batched", method: "initialize", params: valid_initialize_params } ])
    assert_response :bad_request
    assert_equal(-32_600, response.parsed_body.dig("error", "code"))
  end

  test "initialize implementation metadata requires name and version strings" do
    post_json(
      jsonrpc: "2.0",
      id: "missing-client-fields",
      method: "initialize",
      params: {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {},
        clientInfo: {}
      }
    )

    assert_response :ok
    assert_equal(-32_602, response.parsed_body.dig("error", "code"))
    assert_nil response.headers["Mcp-Session-Id"]

    post_json(
      jsonrpc: "2.0",
      id: "empty-client-fields",
      method: "initialize",
      params: {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {},
        clientInfo: { name: "", version: "" }
      }
    )

    assert_response :ok
    assert response.parsed_body["result"]
    assert response.headers["Mcp-Session-Id"].present?
  end

  test "Gateway authentication applies to initialize GET and DELETE with HTTP challenges" do
    config = ActionMCP.configuration
    had_gateway_override = config.instance_variable_defined?(:@gateway_class)
    original_gateway_override = config.instance_variable_get(:@gateway_class)
    ActionMCP.configuration.gateway_class = RejectingGateway

    post_json(jsonrpc: "2.0", id: "auth-init", method: "initialize", params: valid_initialize_params)
    assert_unauthorized_challenge
    assert_nil response.headers["Mcp-Session-Id"]

    get "/"
    assert_unauthorized_challenge

    delete "/", headers: { "Mcp-Session-Id" => "unknown" }
    assert_unauthorized_challenge
  ensure
    if had_gateway_override
      config.gateway_class = original_gateway_override
    else
      config.remove_instance_variable(:@gateway_class) if config.instance_variable_defined?(:@gateway_class)
    end
  end

  test "failed gateway session configuration discards the provisional initialize session" do
    config = ActionMCP.configuration
    had_gateway_override = config.instance_variable_defined?(:@gateway_class)
    original_gateway_override = config.instance_variable_get(:@gateway_class)
    original_count = ActionMCP::Server.session_store.session_count
    config.gateway_class = SessionRejectingGateway

    post_json(jsonrpc: "2.0", id: "rejected-init", method: "initialize", params: valid_initialize_params)

    assert_unauthorized_challenge
    assert_nil response.headers["Mcp-Session-Id"]
    assert_equal original_count, ActionMCP::Server.session_store.session_count
  ensure
    if had_gateway_override
      config.gateway_class = original_gateway_override
    else
      config.remove_instance_variable(:@gateway_class) if config.instance_variable_defined?(:@gateway_class)
    end
  end

  private

  def initialize_session(protocol_version: PROTOCOL_VERSION)
    post_json(
      jsonrpc: "2.0",
      id: "init-#{SecureRandom.hex(4)}",
      method: "initialize",
      params: valid_initialize_params(protocol_version: protocol_version)
    )
    assert_response :ok
    assert response.parsed_body["result"], response.parsed_body.inspect
    response.headers["Mcp-Session-Id"].tap { |id| assert id.present? }
  end

  def complete_initialization(session_id)
    post_json(
      { jsonrpc: "2.0", method: "notifications/initialized" },
      session_id: session_id,
      protocol_version: PROTOCOL_VERSION
    )
  end

  def valid_initialize_params(protocol_version: PROTOCOL_VERSION)
    {
      protocolVersion: protocol_version,
      capabilities: {},
      clientInfo: { name: "stable-test-client", version: "1.0.0" }
    }
  end

  def post_json(payload = nil, session_id: nil, protocol_version: nil, **message)
    payload ||= message
    post "/",
         params: payload.to_json,
         headers: json_headers(session_id: session_id, protocol_version: protocol_version)
  end

  def json_headers(session_id: nil, protocol_version: nil)
    headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json, text/event-stream"
    }
    headers["Mcp-Session-Id"] = session_id if session_id
    headers["MCP-Protocol-Version"] = protocol_version if protocol_version
    headers
  end

  def session_headers(session_id, protocol_version: PROTOCOL_VERSION)
    {
      "Mcp-Session-Id" => session_id,
      "MCP-Protocol-Version" => protocol_version
    }
  end

  def assert_unauthorized_challenge
    assert_response :unauthorized
    assert_match(/\ABearer\b/, response.headers["WWW-Authenticate"])
  end
end
