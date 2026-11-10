# frozen_string_literal: true

require "test_helper"

class ActionMCP::Logging::IntegrationTest < ActionDispatch::IntegrationTest
  include SessionFixtureHelper
  fixtures :action_mcp_sessions
  setup do
    @original_logging_enabled = ActionMCP.configuration.logging_enabled
    @original_logging_level = ActionMCP.configuration.logging_level
    ActionMCP::Logging.reset!

    # Use an initialized session negotiated on the released protocol.
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
    @session.update!(server_capabilities: @session.server_capabilities.except("logging", :logging))
    ActionMCP::Server.session_store.save_session(@session)

    mcp_post("logging/setLevel", { level: "error" }, id: "setlevel-test", protocol_version: "2025-11-25", session_id: @session_id)

    assert_response :success

    result = JSON.parse(response.body)
    assert result.key?("error"), "Should return error when logging disabled"
    assert_equal(-32601, result["error"]["code"])
    assert_match(/not enabled/, result["error"]["message"])
  end

  test "logging/setLevel request succeeds when logging enabled" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.initialize_from_config!

    mcp_post("logging/setLevel", { level: "debug" }, id: "setlevel-test", protocol_version: "2025-11-25", session_id: @session_id)

    assert_response :success

    result = JSON.parse(response.body)
    assert result.key?("result"), "Should return success result"
    assert_equal({}, result["result"])

    assert_equal :debug, ActionMCP::Logging.level_for(@session.reload)
    assert_equal :warning, ActionMCP::Logging.level
  end

  test "logging/setLevel validates log level parameter" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.initialize_from_config!

    mcp_post("logging/setLevel", { level: "invalid_level" }, id: "setlevel-test", protocol_version: "2025-11-25", session_id: @session_id)

    assert_response :success

    result = JSON.parse(response.body)
    assert result.key?("error"), "Should return error for invalid level"
    assert_equal(-32602, result["error"]["code"])
    assert_match(%r{value at `/level` is not one of}, result["error"]["message"])
  end

  test "logging/setLevel requires level parameter" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.initialize_from_config!

    mcp_post("logging/setLevel", {}, id: "setlevel-test", protocol_version: "2025-11-25", session_id: @session_id)

    assert_response :success

    result = JSON.parse(response.body)
    assert result.key?("error"), "Should return error when level parameter missing"
    assert_equal(-32602, result["error"]["code"])
    assert_match(/missing required properties: level/, result["error"]["message"])
  end

  test "default configuration has logging disabled" do
    # Test with fresh configuration
    config = ActionMCP::Configuration.new
    assert_not config.logging_enabled, "Logging should be disabled by default"
    assert_equal :warning, config.logging_level, "Default level should be warning"
  end
end
