# frozen_string_literal: true

require "test_helper"

class ActionMCP::Logging::NullLoggerTest < ActiveSupport::TestCase
  setup do
    @null_logger = ActionMCP::Logging::NullLogger.new
  end

  test "initializes without errors with any arguments" do
    # Should work with no args
    logger1 = ActionMCP::Logging::NullLogger.new
    assert_not_nil logger1

    # Should work with args
    logger2 = ActionMCP::Logging::NullLogger.new("name", session: "session")
    assert_not_nil logger2

    # Should work with keyword args
    logger3 = ActionMCP::Logging::NullLogger.new(name: "test", session: nil, state: nil)
    assert_not_nil logger3
  end

  test "all log level methods return nil" do
    methods = [ :debug, :info, :notice, :warning, :warn, :error, :critical, :alert, :emergency ]

    methods.each do |method|
      # Test with string message
      result = @null_logger.send(method, "test message")
      assert_nil result, "#{method} should return nil"

      # Test with data
      result = @null_logger.send(method, "test", data: { key: "value" })
      assert_nil result, "#{method} with data should return nil"

      # Test with block
      block_called = false
      result = @null_logger.send(method) do
        block_called = true
        "expensive computation"
      end
      assert_nil result, "#{method} with block should return nil"
      assert_not block_called, "#{method} should not call block"
    end
  end

  test "all level check methods return false" do
    methods = [ :debug?, :info?, :notice?, :warning?, :warn?, :error?, :critical?, :alert?, :emergency? ]

    methods.each do |method|
      result = @null_logger.send(method)
      assert_equal false, result, "#{method} should return false"
    end
  end

  test "handles unknown method calls gracefully" do
    # Should not raise NoMethodError
    result = @null_logger.unknown_method("arg1", arg2: "value")
    assert_nil result

    result = @null_logger.another_unknown_method
    assert_nil result
  end

  test "responds to any method" do
    assert @null_logger.respond_to?(:debug)
    assert @null_logger.respond_to?(:info?)
    assert @null_logger.respond_to?(:unknown_method)
    assert @null_logger.respond_to?(:any_method_at_all)
  end

  test "provides zero overhead logging interface" do
    # These operations should be very fast and not raise errors
    1000.times do
      @null_logger.debug("message")
      @null_logger.info { "expensive computation that won't run" }
      @null_logger.error("error", data: { large: "data structure" })
      @null_logger.debug?
      @null_logger.unknown_method(1, 2, 3, key: "value")
    end

    # If we get here without timeout, performance is acceptable
    assert true
  end

  test "blocks are never evaluated" do
    expensive_operation_called = false

    @null_logger.debug do
      expensive_operation_called = true
      "This should never be evaluated"
    end

    assert_not expensive_operation_called, "Block should not be evaluated in NullLogger"
  end
end
