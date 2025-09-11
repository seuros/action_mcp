# frozen_string_literal: true

require "test_helper"

class ActionMCP::Logging::StateTest < ActiveSupport::TestCase
  setup do
    @state = ActionMCP::Logging::State.new
  end

  teardown do
    @state.reset!
  end

  test "initializes with disabled state and warning level" do
    assert_not @state.enabled?
    assert_equal 3, @state.level # warning = 3
    assert_equal :warning, @state.level_symbol
  end

  test "can enable and disable logging" do
    # Start disabled
    assert_not @state.enabled?

    # Enable
    result = @state.enable!
    assert result
    assert @state.enabled?

    # Disable
    result = @state.disable!
    assert result # make_false returns true on success
    assert_not @state.enabled?
  end

  test "can set enabled state with boolean" do
    @state.enabled = true
    assert @state.enabled?

    @state.enabled = false
    assert_not @state.enabled?
  end

  test "can set and get log level with symbols" do
    @state.level = :debug
    assert_equal 0, @state.level
    assert_equal :debug, @state.level_symbol

    @state.level = :emergency
    assert_equal 7, @state.level
    assert_equal :emergency, @state.level_symbol
  end

  test "can set log level with strings" do
    @state.level = "info"
    assert_equal 1, @state.level
    assert_equal :info, @state.level_symbol
  end

  test "can set log level with integers" do
    @state.level = 4
    assert_equal 4, @state.level
    assert_equal :error, @state.level_symbol
  end

  test "raises ArgumentError for invalid levels" do
    assert_raises(ArgumentError) { @state.level = "invalid" }
    assert_raises(ArgumentError) { @state.level = 8 }
  end

  test "should_log returns false when disabled" do
    @state.disable!

    # Should be false for all levels when disabled
    ActionMCP::Logging::Level.all_levels.each do |level|
      assert_not @state.should_log?(level), "should_log?(#{level}) should be false when disabled"
    end
  end

  test "should_log respects level hierarchy when enabled" do
    @state.enable!
    @state.level = :warning

    # Should log warning and above
    assert @state.should_log?(:warning)
    assert @state.should_log?(:error)
    assert @state.should_log?(:critical)
    assert @state.should_log?(:alert)
    assert @state.should_log?(:emergency)

    # Should not log below warning
    assert_not @state.should_log?(:debug)
    assert_not @state.should_log?(:info)
    assert_not @state.should_log?(:notice)
  end

  test "should_log works with different level formats" do
    @state.enable!
    @state.level = :error

    # Test with symbol, string, and integer
    assert @state.should_log?(:error)
    assert @state.should_log?("error")
    assert @state.should_log?(4)

    assert_not @state.should_log?(:warning)
    assert_not @state.should_log?("warning")
    assert_not @state.should_log?(3)
  end

  test "reset! returns to initial state" do
    @state.enable!
    @state.level = :debug

    @state.reset!

    assert_not @state.enabled?
    assert_equal :warning, @state.level_symbol
  end

  test "is thread-safe" do
    threads = []
    results = []

    # Test concurrent enable/disable operations
    10.times do |i|
      threads << Thread.new do
        if i.even?
          @state.enable!
        else
          @state.disable!
        end
        results << @state.enabled?
      end
    end

    threads.each(&:join)

    # Should get a mix of true/false, but no exceptions
    assert results.any? { |r| r }
    assert results.any? { |r| !r }
  end

  test "level changes are thread-safe" do
    @state.enable!
    threads = []
    final_levels = []

    # Test concurrent level changes
    levels = [ :debug, :info, :warning, :error ]
    10.times do |i|
      threads << Thread.new do
        @state.level = levels[i % levels.length]
        final_levels << @state.level_symbol
      end
    end

    threads.each(&:join)

    # Should get valid levels, no exceptions
    final_levels.each do |level|
      assert ActionMCP::Logging::Level.all_levels.include?(level)
    end
  end
end
