# frozen_string_literal: true

require "test_helper"

class ActionMCP::Logging::IntegrationTest < ActionDispatch::IntegrationTest
  include SessionFixtureHelper
  fixtures :action_mcp_sessions
  setup do
    @original_logging_enabled = ActionMCP.configuration.logging_enabled
    @original_logging_level = ActionMCP.configuration.logging_level
    ActionMCP::Logging.reset!

    # Use initialized session from fixtures with 2025-06-18 protocol
    @session = action_mcp_sessions(:dr_identity_mcbouncer_session)

    # Ensure session is in the session store
    store = ActionMCP::Server.session_store
    store.save_session(@session)
    store.load_session(@session.id)

    @session_id = @session.id
  end

  teardown do
    ActionMCP.configuration.logging_enabled = @original_logging_enabled
    ActionMCP.configuration.logging_level = @original_logging_level
    ActionMCP::Logging.reset!
  end


  test "logging/setLevel request fails when logging disabled" do
    ActionMCP.configuration.logging_enabled = false

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "setlevel-test",
        method: "logging/setLevel",
        params: { level: "error" }
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "MCP-Protocol-Version" => "2025-06-18",
        "Mcp-Session-Id" => @session_id
      }

    assert_response :success

    result = JSON.parse(response.body)
    assert result.key?("error"), "Should return error when logging disabled"
    assert_equal(-32601, result["error"]["code"])
    assert_match(/not enabled/, result["error"]["message"])
  end

  test "logging/setLevel request succeeds when logging enabled" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.initialize_from_config!

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "setlevel-test",
        method: "logging/setLevel",
        params: { level: "debug" }
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "MCP-Protocol-Version" => "2025-06-18",
        "Mcp-Session-Id" => @session_id
      }

    assert_response :success

    result = JSON.parse(response.body)
    assert result.key?("result"), "Should return success result"
    assert_equal({}, result["result"])

    # Verify level was actually set
    assert_equal :debug, ActionMCP::Logging.level
  end

  test "logging/setLevel validates log level parameter" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.initialize_from_config!

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "setlevel-test",
        method: "logging/setLevel",
        params: { level: "invalid_level" }
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "MCP-Protocol-Version" => "2025-06-18",
        "Mcp-Session-Id" => @session_id
      }

    assert_response :success

    result = JSON.parse(response.body)
    assert result.key?("error"), "Should return error for invalid level"
    assert_equal(-32602, result["error"]["code"])
    assert_match(/Invalid log level/, result["error"]["message"])
  end

  test "logging/setLevel requires level parameter" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.initialize_from_config!

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "setlevel-test",
        method: "logging/setLevel",
        params: {}
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "MCP-Protocol-Version" => "2025-06-18",
        "Mcp-Session-Id" => @session_id
      }

    assert_response :success

    result = JSON.parse(response.body)
    assert result.key?("error"), "Should return error when level parameter missing"
    assert_equal(-32602, result["error"]["code"])
    assert_match(/Missing required parameter: level/, result["error"]["message"])
  end

  test "default configuration has logging disabled" do
    # Test with fresh configuration
    config = ActionMCP::Configuration.new
    assert_not config.logging_enabled, "Logging should be disabled by default"
    assert_equal :warning, config.logging_level, "Default level should be warning"
  end
end
