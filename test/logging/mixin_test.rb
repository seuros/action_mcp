# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ActionMCP::Logging::MixinTest < ActiveSupport::TestCase
  # Test class that includes the mixin
  class TestTool
    include ActionMCP::Logging::Mixin

    attr_accessor :execution_context

    def initialize
      @execution_context = {}
    end

    def self.name
      "TestTool"
    end
  end

  setup do
    @original_logging_enabled = ActionMCP.configuration.logging_enabled
    ActionMCP::Logging.reset!
    @tool = TestTool.new
    @sent_notifications = []
  end

  teardown do
    ActionMCP.configuration.logging_enabled = @original_logging_enabled
    ActionMCP::Logging.reset!
  end

  test "provides all log level methods" do
    methods = [ :mcp_debug, :mcp_info, :mcp_notice, :mcp_warning, :mcp_warn,
               :mcp_error, :mcp_critical, :mcp_alert, :mcp_emergency ]

    methods.each do |method|
      assert_respond_to @tool, method, "Tool should respond to #{method}"
    end
  end

  test "provides all level check methods" do
    methods = [ :mcp_debug?, :mcp_info?, :mcp_notice?, :mcp_warning?, :mcp_warn?,
               :mcp_error?, :mcp_critical?, :mcp_alert?, :mcp_emergency? ]

    methods.each do |method|
      assert_respond_to @tool, method, "Tool should respond to #{method}"
    end
  end

  test "returns NullLogger when logging disabled" do
    ActionMCP.configuration.logging_enabled = false

    logger = @tool.mcp_logger
    assert_instance_of ActionMCP::Logging::NullLogger, logger
  end

  test "returns real Logger when enabled with session" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.enable!

    session = mock_session
    @tool.execution_context = { session: session }

    logger = @tool.mcp_logger
    assert_instance_of ActionMCP::Logging::Logger, logger
  end

  test "returns NullLogger when enabled but no session" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.enable!

    @tool.execution_context = {}

    logger = @tool.mcp_logger
    assert_instance_of ActionMCP::Logging::NullLogger, logger
  end

  test "generates logger name from class name" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.enable!

    session = mock_session
    @tool.execution_context = { session: session }

    logger = @tool.mcp_logger
    assert_equal "test_tool", logger.name
  end

  test "caches logger instance" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.enable!

    session = mock_session
    @tool.execution_context = { session: session }

    logger1 = @tool.mcp_logger
    logger2 = @tool.mcp_logger

    assert_same logger1, logger2, "Logger should be cached"
  end

  test "log methods call through to logger" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.enable!
    ActionMCP::Logging.level = :debug

    session = mock_session_with_messaging
    @tool.execution_context = { session: session }

    @tool.mcp_debug("debug message")
    @tool.mcp_info("info message", data: { key: "value" })
    @tool.mcp_error { "error from block" }

    assert_equal 3, @sent_notifications.length

    assert_equal "debug", @sent_notifications[0][:params][:level]
    assert_equal "info", @sent_notifications[1][:params][:level]
    assert_equal "error", @sent_notifications[2][:params][:level]
  end

  test "level check methods work correctly" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.enable!
    ActionMCP::Logging.level = :warning

    session = mock_session
    @tool.execution_context = { session: session }

    # Should be false for levels below warning
    assert_not @tool.mcp_debug?
    assert_not @tool.mcp_info?
    assert_not @tool.mcp_notice?

    # Should be true for warning and above
    assert @tool.mcp_warning?
    assert @tool.mcp_error?
    assert @tool.mcp_critical?
    assert @tool.mcp_alert?
    assert @tool.mcp_emergency?
  end

  test "warn alias works" do
    ActionMCP.configuration.logging_enabled = true
    ActionMCP::Logging.state.enable!
    ActionMCP::Logging.level = :debug

    session = mock_session_with_messaging
    @tool.execution_context = { session: session }

    @tool.mcp_warn("warning message")

    assert_equal 1, @sent_notifications.length
    assert_equal "warning", @sent_notifications[0][:params][:level]
  end

  test "all methods are no-op when disabled" do
    ActionMCP.configuration.logging_enabled = false

    # Should not raise errors
    @tool.mcp_debug("message")
    @tool.mcp_info { "expensive computation" }
    @tool.mcp_error("error", data: { key: "value" })

    # Should all return false
    assert_not @tool.mcp_debug?
    assert_not @tool.mcp_error?
    assert_not @tool.mcp_emergency?
  end

  private

  def mock_session
    session = Minitest::Mock.new
    messaging_service = Minitest::Mock.new
    session.expect(:messaging_service, messaging_service)
    session
  end

  def mock_session_with_messaging
    session = Minitest::Mock.new
    messaging_service = Minitest::Mock.new

    # Expect send_notification calls and capture them
    messaging_service.expect(:send_notification, nil) do |method, params|
      @sent_notifications << { method: method, params: params }
      true
    end
    messaging_service.expect(:send_notification, nil) do |method, params|
      @sent_notifications << { method: method, params: params }
      true
    end
    messaging_service.expect(:send_notification, nil) do |method, params|
      @sent_notifications << { method: method, params: params }
      true
    end

    session.expect(:messaging_service, messaging_service)
    session.expect(:messaging_service, messaging_service)
    session.expect(:messaging_service, messaging_service)
    session
  end
end
