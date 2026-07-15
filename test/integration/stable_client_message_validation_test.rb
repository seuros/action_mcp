# frozen_string_literal: true

require "test_helper"

class StableClientMessageValidationTest < ActionDispatch::IntegrationTest
  PROTOCOL_VERSION = "2025-11-25"

  INVALID_REQUEST_PARAMS = {
    "ping" => { _meta: { progressToken: [] } },
    "resources/list" => { cursor: 1 },
    "resources/templates/list" => { cursor: 1 },
    "resources/read" => { uri: 1 },
    "resources/subscribe" => { uri: 1 },
    "resources/unsubscribe" => { uri: 1 },
    "prompts/list" => { cursor: 1 },
    "prompts/get" => { name: "analyze_code", arguments: { language: 1 } },
    "tools/list" => { cursor: 1 },
    "tools/call" => { name: 1 },
    "tasks/get" => { taskId: 1 },
    "tasks/result" => { taskId: 1 },
    "tasks/cancel" => { taskId: 1 },
    "tasks/list" => { cursor: 1 },
    "logging/setLevel" => { level: "verbose" },
    "completion/complete" => {
      argument: { name: 1, value: "ru" },
      ref: { type: "ref/prompt", name: "analyze_code" }
    }
  }.freeze

  REQUIRED_REQUEST_PARAMS = %w[
    resources/read
    resources/subscribe
    resources/unsubscribe
    prompts/get
    tools/call
    tasks/get
    tasks/result
    tasks/cancel
    logging/setLevel
    completion/complete
  ].freeze

  INVALID_INITIALIZE_PARAMS = {
    "request metadata" => { _meta: { progressToken: [] } },
    "protocol version" => { protocolVersion: 1 },
    "root capabilities" => { capabilities: { roots: { listChanged: "yes" } } },
    "experimental capabilities" => { capabilities: { experimental: { vendor: true } } },
    "task request capabilities" => {
      capabilities: { tasks: { requests: { sampling: { createMessage: true } } } }
    },
    "implementation title" => { clientInfo: { title: 1 } },
    "implementation icons" => { clientInfo: { icons: [ { src: 1 } ] } },
    "implementation icon sizes" => {
      clientInfo: { icons: [ { src: "https://example.test/icon.png", sizes: [ 48 ] } ] }
    },
    "implementation icon theme" => {
      clientInfo: { icons: [ { src: "https://example.test/icon.png", theme: "auto" } ] }
    }
  }.freeze

  test "accepts the full stable initialize shape and extension fields" do
    post_json(
      {
        jsonrpc: "2.0",
        id: "full-init",
        method: "initialize",
        traceId: "top-level-extension",
        params: {
          protocolVersion: PROTOCOL_VERSION,
          _meta: { progressToken: "init-progress", vendor: true },
          clientInfo: {
            name: "stable-client",
            title: "Stable Client",
            version: "1.0.0",
            description: "Exercises every released implementation field",
            websiteUrl: "https://example.test/client",
            icons: [
              {
                src: "https://example.test/icon.png",
                mimeType: "image/png",
                sizes: %w[48x48 any],
                theme: "dark",
                vendor: true
              }
            ],
            vendor: true
          },
          capabilities: {
            elicitation: { form: { vendor: true }, url: {} },
            experimental: { vendor: { enabled: true } },
            roots: { listChanged: true, vendor: true },
            sampling: { context: {}, tools: {} },
            tasks: {
              cancel: {},
              list: {},
              requests: {
                elicitation: { create: {} },
                sampling: { createMessage: {} }
              }
            },
            vendor: { enabled: true }
          },
          vendor: true
        }
      }
    )

    assert_response :ok
    assert response.parsed_body["result"]
    assert response.headers["Mcp-Session-Id"].present?
  end

  test "rejects invalid nested initialize fields before allocating a session" do
    INVALID_INITIALIZE_PARAMS.each do |label, override|
      params = deep_merge(valid_initialize_params, override)
      post_json(jsonrpc: "2.0", id: "invalid-#{label}", method: "initialize", params: params)

      assert_response :ok, label
      assert_equal(-32_602, response.parsed_body.dig("error", "code"), label)
      assert_nil response.headers["Mcp-Session-Id"], label
    end
  end

  test "returns invalid params for every malformed stable client request variant" do
    session_id = create_initialized_session

    INVALID_REQUEST_PARAMS.each_with_index do |(method, params), index|
      post_json(
        { jsonrpc: "2.0", id: "invalid-#{index}", method: method, params: params },
        session_id: session_id
      )

      assert_response :ok, method
      assert_equal(-32_602, response.parsed_body.dig("error", "code"), method)
    end
  end

  test "does not coerce omitted params required by stable client requests" do
    session_id = create_initialized_session

    REQUIRED_REQUEST_PARAMS.each_with_index do |method, index|
      post_json(
        { jsonrpc: "2.0", id: "missing-#{index}", method: method },
        session_id: session_id
      )

      assert_response :ok, method
      assert_equal(-32_602, response.parsed_body.dig("error", "code"), method)
    end
  end

  test "validates tool metadata and task TTL before capability fallback" do
    session_id = create_initialized_session
    invalid_calls = [
      { name: "add", _meta: "opaque" },
      { name: "add", task: { ttl: "60000" } }
    ]

    invalid_calls.each_with_index do |params, index|
      post_json(
        { jsonrpc: "2.0", id: "invalid-tool-#{index}", method: "tools/call", params: params },
        session_id: session_id
      )

      assert_response :ok
      assert_equal(-32_602, response.parsed_body.dig("error", "code"))
    end
  end

  test "rejects malformed fields for every stable client notification variant" do
    session_id = create_initialized_session
    invalid_notifications = {
      "notifications/cancelled" => nil,
      "notifications/initialized" => { _meta: "opaque" },
      "notifications/progress" => { progressToken: [], progress: 1 },
      "notifications/tasks/status" => {
        taskId: "task-1",
        status: "queued",
        ttl: nil,
        createdAt: "2026-01-01T00:00:00Z",
        lastUpdatedAt: "2026-01-01T00:00:00Z"
      },
      "notifications/roots/list_changed" => { _meta: "opaque" }
    }

    invalid_notifications.each do |method, params|
      payload = { jsonrpc: "2.0", method: method }
      payload[:params] = params unless params.nil?
      post_json(payload, session_id: session_id)

      assert_response :bad_request, method
      assert_equal(-32_602, response.parsed_body.dig("error", "code"), method)
    end
  end

  test "does not initialize a session from malformed initialized metadata" do
    session_id = create_initializing_session
    session = ActionMCP::Server.session_store.load_session(session_id)
    refute session.initialized?

    post_json(
      {
        jsonrpc: "2.0",
        method: "notifications/initialized",
        params: { _meta: "opaque" }
      },
      session_id: session_id
    )

    assert_response :bad_request
    assert_equal(-32_602, response.parsed_body.dig("error", "code"))
    refute session.reload.initialized?
    assert_equal "initializing", session.status
  end

  test "returns an HTTP error for notifications outside the stable client union" do
    session_id = create_initialized_session

    post_json(
      { jsonrpc: "2.0", method: "notifications/tools/list_changed", params: {} },
      session_id: session_id
    )

    assert_response :bad_request
    assert_equal(-32_601, response.parsed_body.dig("error", "code"))
  end

  test "accepts stable cancellation without requestId as allowed by the formal schema" do
    session_id = create_initialized_session

    post_json(
      { jsonrpc: "2.0", method: "notifications/cancelled", params: { vendor: true } },
      session_id: session_id,
      extensions: { traceId: "notification-extension" }
    )

    assert_response :accepted
  end

  test "accepts valid unmatched progress and task status notifications" do
    session_id = create_initialized_session
    notifications = [
      {
        jsonrpc: "2.0",
        method: "notifications/progress",
        params: {
          progressToken: 7,
          progress: 1.5,
          total: 3,
          message: "Working",
          vendor: true
        }
      },
      {
        jsonrpc: "2.0",
        method: "notifications/tasks/status",
        params: {
          taskId: "client-task-1",
          status: "working",
          ttl: nil,
          createdAt: "2026-01-01T00:00:00Z",
          lastUpdatedAt: "2026-01-01T00:00:01Z",
          pollInterval: 1000,
          statusMessage: "Working",
          vendor: true
        }
      }
    ]

    notifications.each do |payload|
      post_json(payload, session_id: session_id)
      assert_response :accepted, payload[:method]
    end
  end

  private

  def create_initializing_session
    post_json(jsonrpc: "2.0", id: "init", method: "initialize", params: valid_initialize_params)
    assert_response :ok
    session_id = response.headers["Mcp-Session-Id"]
    assert session_id.present?
    session_id
  end

  def create_initialized_session
    session_id = create_initializing_session

    post_json(
      { jsonrpc: "2.0", method: "notifications/initialized" },
      session_id: session_id
    )
    assert_response :accepted
    session_id
  end

  def valid_initialize_params
    {
      protocolVersion: PROTOCOL_VERSION,
      capabilities: {},
      clientInfo: { name: "stable-client", version: "1.0.0" }
    }
  end

  def post_json(payload = nil, session_id: nil, extensions: {}, **message)
    payload ||= message
    payload = payload.merge(extensions)
    headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json, text/event-stream"
    }
    if session_id
      headers["Mcp-Session-Id"] = session_id
      headers["MCP-Protocol-Version"] = PROTOCOL_VERSION
    end

    post "/", params: payload.to_json, headers: headers
  end

  def deep_merge(base, override)
    base.deep_merge(override)
  end
end
