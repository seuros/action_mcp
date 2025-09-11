# frozen_string_literal: true

require "test_helper"

class ActionMCP::Logging::IntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @original_logging_enabled = ActionMCP.configuration.logging_enabled
    @original_logging_level = ActionMCP.configuration.logging_level
    ActionMCP::Logging.reset!

    # Create a test session
    @session = ActionMCP::Session.create!(
      status: "initialized",
      protocol_version: "2025-06-18",
      client_info: { name: "test-client", version: "1.0.0" }
    )
  end

  teardown do
    ActionMCP.configuration.logging_enabled = @original_logging_enabled
    ActionMCP.configuration.logging_level = @original_logging_level
    ActionMCP::Logging.reset!
  end

  test "logging capability is not advertised when disabled" do
    ActionMCP.configuration.logging_enabled = false

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "test",
        method: "initialize",
        params: { protocolVersion: "2025-06-18", clientInfo: { name: "test", version: "1.0" } }
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "MCP-Protocol-Version" => "2025-06-18"
      }

    assert_response :success

    result = JSON.parse(response.body)
    capabilities = result.dig("result", "capabilities")

    assert_not capabilities.key?("logging"), "logging capability should not be advertised when disabled"
  end

  test "logging capability is advertised when enabled" do
    ActionMCP.configuration.logging_enabled = true

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "test",
        method: "initialize",
        params: { protocolVersion: "2025-06-18", clientInfo: { name: "test", version: "1.0" } }
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "MCP-Protocol-Version" => "2025-06-18"
      }

    assert_response :success

    result = JSON.parse(response.body)
    capabilities = result.dig("result", "capabilities")

    assert capabilities.key?("logging"), "logging capability should be advertised when enabled"
    assert_equal({}, capabilities["logging"])
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
        "MCP-Protocol-Version" => "2025-06-18",
        "Mcp-Session-Id" => @session.id
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
        "MCP-Protocol-Version" => "2025-06-18",
        "Mcp-Session-Id" => @session.id
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
        "MCP-Protocol-Version" => "2025-06-18",
        "Mcp-Session-Id" => @session.id
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
        "MCP-Protocol-Version" => "2025-06-18",
        "Mcp-Session-Id" => @session.id
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

  test "configuration change affects capability advertisement" do
    # First request with logging disabled
    ActionMCP.configuration.logging_enabled = false

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "test1",
        method: "initialize",
        params: { protocolVersion: "2025-06-18", clientInfo: { name: "test", version: "1.0" } }
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "MCP-Protocol-Version" => "2025-06-18"
      }

    result1 = JSON.parse(response.body)
    capabilities1 = result1.dig("result", "capabilities")
    assert_not capabilities1.key?("logging")

    # Enable logging and make another request
    ActionMCP.configuration.logging_enabled = true

    post "/",
      params: {
        jsonrpc: "2.0",
        id: "test2",
        method: "initialize",
        params: { protocolVersion: "2025-06-18", clientInfo: { name: "test", version: "1.0" } }
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "MCP-Protocol-Version" => "2025-06-18"
      }

    result2 = JSON.parse(response.body)
    capabilities2 = result2.dig("result", "capabilities")
    assert capabilities2.key?("logging")
  end
end
