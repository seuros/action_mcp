# frozen_string_literal: true

require "test_helper"

class ActionMCP::Server::Handlers::LoggingHandlerTest < ActiveSupport::TestCase
  include ActionMCP::Server::Handlers::LoggingHandler

  setup do
    ActionMCP::Logging.reset!
    @sent_responses = []
    @sent_errors = []
    @session = ActionMCP::Server::BaseSession.new(
      server_capabilities: { "logging" => {} },
      session_data: {}
    )

    # Mock transport
    @transport = Object.new
    @transport.instance_variable_set(:@session, @session)
    def @transport.session
      @session
    end
    def @transport.send_jsonrpc_response(id, result:)
      @sent_responses << { id: id, result: result }
    end
    def @transport.send_jsonrpc_error(id, code, message)
      @sent_errors << { id: id, code: code, message: message }
    end

    # Make instance variables accessible
    @transport.instance_variable_set(:@sent_responses, @sent_responses)
    @transport.instance_variable_set(:@sent_errors, @sent_errors)
  end

  teardown do
    ActionMCP::Logging.reset!
  end

  test "handle_logging_set_level succeeds when enabled with valid level" do
    handle_logging_set_level("test-id", { level: "error" })

    assert_equal 1, @sent_responses.length
    response = @sent_responses.first
    assert_equal "test-id", response[:id]
    assert_equal({}, response[:result])
    assert_equal :error, ActionMCP::Logging.level_for(@session)
    assert_equal :warning, ActionMCP::Logging.level
  end

  test "handle_logging_set_level works with symbol parameter" do
    handle_logging_set_level("test-id", { level: :debug })

    assert_equal 1, @sent_responses.length
    assert_equal :debug, ActionMCP::Logging.level_for(@session)
  end

  test "handle_logging_set_level works with string key" do
    handle_logging_set_level("test-id", { "level" => "info" })

    assert_equal 1, @sent_responses.length
    assert_equal :info, ActionMCP::Logging.level_for(@session)
  end

  test "handle_logging_set_level returns error when disabled" do
    @session.server_capabilities = {}

    handle_logging_set_level("test-id", { level: "error" })

    assert_equal 1, @sent_errors.length
    error = @sent_errors.first
    assert_equal "test-id", error[:id]
    assert_equal(:method_not_found, error[:code])
    assert_equal "Logging not enabled", error[:message]
  end

  test "handle_logging_set_level returns error when level parameter missing" do
    handle_logging_set_level("test-id", {})

    assert_equal 1, @sent_errors.length
    error = @sent_errors.first
    assert_equal "test-id", error[:id]
    assert_equal(:invalid_params, error[:code])
    assert_equal "Missing required parameter: level", error[:message]
  end

  test "handle_logging_set_level returns error for invalid level" do
    handle_logging_set_level("test-id", { level: "invalid" })

    assert_equal 1, @sent_errors.length
    error = @sent_errors.first
    assert_equal "test-id", error[:id]
    assert_equal(:invalid_params, error[:code])
    assert_match(/Invalid log level/, error[:message])
  end

  test "handle_logging_set_level handles internal errors gracefully" do
    original_method = ActionMCP::Logging.method(:set_level_for)
    ActionMCP::Logging.define_singleton_method(:set_level_for) do |_, _|
      raise StandardError, "internal error"
    end

    begin
      handle_logging_set_level("test-id", { level: "info" })
    ensure
      ActionMCP::Logging.define_singleton_method(:set_level_for, original_method)
    end

    assert_equal 1, @sent_errors.length
    error = @sent_errors.first
    assert_equal "test-id", error[:id]
    assert_equal(:internal_error, error[:code])
    assert_match(/Internal error/, error[:message])
  end

  test "handle_logging_set_level rejects non-object params" do
    handle_logging_set_level("test-id", [ "debug" ])

    assert_equal 1, @sent_errors.length
    assert_equal :invalid_params, @sent_errors.first[:code]
    assert_equal "Logging params must be an object", @sent_errors.first[:message]
  end

  private

  # Provide access to the mock transport
  def transport
    @transport
  end

  # Mock the JSON-RPC response methods (kept for backward compatibility)
  def send_jsonrpc_response(id, result:)
    @sent_responses << { id: id, result: result }
  end

  def send_jsonrpc_error(id, code, message)
    @sent_errors << { id: id, code: code, message: message }
  end
end
