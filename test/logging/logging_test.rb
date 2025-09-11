# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ActionMCP::LoggingTest < ActiveSupport::TestCase
  setup do
    @original_logging_enabled = ActionMCP.configuration.logging_enabled
    @original_logging_level = ActionMCP.configuration.logging_level
    ActionMCP::Logging.reset!
  end

  teardown do
    ActionMCP.configuration.logging_enabled = @original_logging_enabled
    ActionMCP.configuration.logging_level = @original_logging_level
    ActionMCP::Logging.reset!
  end

  test "initializes from configuration correctly when enabled" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP.configuration.logging_level = :debug

    ActionMCP::Logging.initialize_from_config!

    assert ActionMCP::Logging.enabled?
    assert_equal :debug, ActionMCP::Logging.level
  end

  test "initializes from configuration correctly when disabled" do
    ActionMCP.configuration.logging_enabled = false
    ActionMCP.configuration.logging_level = :info

    ActionMCP::Logging.initialize_from_config!

    assert_not ActionMCP::Logging.enabled?
    # Note: Level is still set even when disabled for future enabling
    assert_equal :info, ActionMCP::Logging.level
  end

  test "enabled? considers both configuration and state" do
    # Configuration disabled
    ActionMCP.configuration.logging_enabled = false
    ActionMCP::Logging.state.enable!
    assert_not ActionMCP::Logging.enabled?

    # Configuration enabled but state disabled
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.disable!
    assert_not ActionMCP::Logging.enabled?

    # Both enabled
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.enable!
    assert ActionMCP::Logging.enabled?
  end

  test "can enable and disable logging" do
    # Enable
    result = ActionMCP::Logging.enable!
    assert result
    assert ActionMCP.configuration.logging_enabled
    assert ActionMCP::Logging.state.enabled?
    assert ActionMCP::Logging.enabled?

    # Disable
    result = ActionMCP::Logging.disable!
    assert result # disable! returns true on success
    assert_not ActionMCP::Logging.state.enabled?
    # Note: Configuration is not changed by disable!, only state
  end

  test "can set and get log level" do
    ActionMCP::Logging.level = :error
    assert_equal :error, ActionMCP::Logging.level

    ActionMCP::Logging.set_level("debug")
    assert_equal :debug, ActionMCP::Logging.level
  end

  test "returns NullLogger when disabled" do
    ActionMCP.configuration.logging_enabled = false

    session = mock_session
    logger = ActionMCP::Logging.logger(name: "test", session: session)

    assert_instance_of ActionMCP::Logging::NullLogger, logger
  end

  test "returns real Logger when enabled" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.enable!

    session = mock_session
    logger = ActionMCP::Logging.logger(name: "test", session: session)

    assert_instance_of ActionMCP::Logging::Logger, logger
  end

  test "logger_for_context works with execution context" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.enable!

    session = mock_session
    execution_context = { session: session }

    logger = ActionMCP::Logging.logger_for_context(
      name: "test",
      execution_context: execution_context
    )

    assert_instance_of ActionMCP::Logging::Logger, logger
  end

  test "logger_for_context returns NullLogger when no session" do
    execution_context = {}

    logger = ActionMCP::Logging.logger_for_context(
      name: "test",
      execution_context: execution_context
    )

    assert_instance_of ActionMCP::Logging::NullLogger, logger
  end

  test "reset! restores initial state" do
    ActionMCP::Logging.enable!
    ActionMCP::Logging.level = :debug

    ActionMCP::Logging.reset!

    assert_not ActionMCP::Logging.state.enabled?
    assert_equal :warning, ActionMCP::Logging.level
  end

  private

  def mock_session
    session = Minitest::Mock.new
    messaging_service = Minitest::Mock.new
    session.expect(:messaging_service, messaging_service)
    session
  end
end
