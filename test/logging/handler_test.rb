# frozen_string_literal: true

require "test_helper"

class ActionMCP::Server::Handlers::LoggingHandlerTest < ActiveSupport::TestCase
  include ActionMCP::Server::Handlers::LoggingHandler

  setup do
    @original_logging_enabled = ActionMCP.configuration.logging_enabled
    ActionMCP::Logging.reset!
    @sent_responses = []
    @sent_errors = []
  end

  teardown do
    ActionMCP.configuration.logging_enabled = @original_logging_enabled
    ActionMCP::Logging.reset!
  end

  test "handle_logging_set_level succeeds when enabled with valid level" do
    ActionMCP.configuration.logging_enabled = true

    handle_logging_set_level("test-id", { level: "error" })

    assert_equal 1, @sent_responses.length
    response = @sent_responses.first
    assert_equal "test-id", response[:id]
    assert_equal({}, response[:result])
    assert_equal :error, ActionMCP::Logging.level
  end

  test "handle_logging_set_level works with symbol parameter" do
    ActionMCP.configuration.logging_enabled = true

    handle_logging_set_level("test-id", { level: :debug })

    assert_equal 1, @sent_responses.length
    assert_equal :debug, ActionMCP::Logging.level
  end

  test "handle_logging_set_level works with string key" do
    ActionMCP.configuration.logging_enabled = true

    handle_logging_set_level("test-id", { "level" => "info" })

    assert_equal 1, @sent_responses.length
    assert_equal :info, ActionMCP::Logging.level
  end

  test "handle_logging_set_level returns error when disabled" do
    ActionMCP.configuration.logging_enabled = false

    handle_logging_set_level("test-id", { level: "error" })

    assert_equal 1, @sent_errors.length
    error = @sent_errors.first
    assert_equal "test-id", error[:id]
    assert_equal(-32601, error[:code])
    assert_equal "Logging not enabled", error[:message]
  end

  test "handle_logging_set_level returns error when level parameter missing" do
    ActionMCP.configuration.logging_enabled = true

    handle_logging_set_level("test-id", {})

    assert_equal 1, @sent_errors.length
    error = @sent_errors.first
    assert_equal "test-id", error[:id]
    assert_equal(-32602, error[:code])
    assert_equal "Missing required parameter: level", error[:message]
  end

  test "handle_logging_set_level returns error for invalid level" do
    ActionMCP.configuration.logging_enabled = true

    handle_logging_set_level("test-id", { level: "invalid" })

    assert_equal 1, @sent_errors.length
    error = @sent_errors.first
    assert_equal "test-id", error[:id]
    assert_equal(-32602, error[:code])
    assert_match(/Invalid log level/, error[:message])
  end

  test "handle_logging_set_level handles internal errors gracefully" do
    ActionMCP.configuration.logging_enabled = true

    # Mock ActionMCP::Logging.set_level to raise an error
    original_method = ActionMCP::Logging.method(:set_level)
    ActionMCP::Logging.define_singleton_method(:set_level) do |_|
      raise StandardError, "internal error"
    end

    begin
      handle_logging_set_level("test-id", { level: "info" })
    ensure
      # Restore original method
      ActionMCP::Logging.define_singleton_method(:set_level, original_method)
    end

    assert_equal 1, @sent_errors.length
    error = @sent_errors.first
    assert_equal "test-id", error[:id]
    assert_equal(-32603, error[:code])
    assert_match(/Internal error/, error[:message])
  end

  private

  # Mock the JSON-RPC response methods
  def send_jsonrpc_response(id, result:)
    @sent_responses << { id: id, result: result }
  end

  def send_jsonrpc_error(id, code, message)
    @sent_errors << { id: id, code: code, message: message }
  end
end
