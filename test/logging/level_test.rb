# frozen_string_literal: true

require "test_helper"

class ActionMCP::Logging::LevelTest < ActiveSupport::TestCase
  test "defines RFC 5424 levels in correct order" do
    expected_levels = {
      debug: 0,
      info: 1,
      notice: 2,
      warning: 3,
      error: 4,
      critical: 5,
      alert: 6,
      emergency: 7
    }

    assert_equal expected_levels, ActionMCP::Logging::Level::LEVELS
  end

  test "validates valid string levels" do
    %w[debug info notice warning error critical alert emergency].each do |level|
      assert ActionMCP::Logging::Level.valid?(level), "#{level} should be valid"
    end
  end

  test "validates valid symbol levels" do
    [ :debug, :info, :notice, :warning, :error, :critical, :alert, :emergency ].each do |level|
      assert ActionMCP::Logging::Level.valid?(level), "#{level} should be valid"
    end
  end

  test "validates valid integer levels" do
    (0..7).each do |level|
      assert ActionMCP::Logging::Level.valid?(level), "#{level} should be valid"
    end
  end

  test "rejects invalid levels" do
    [ "invalid", :invalid, 8, -1, nil, [] ].each do |level|
      assert_not ActionMCP::Logging::Level.valid?(level), "#{level.inspect} should be invalid"
    end
  end

  test "coerces string levels to integers" do
    assert_equal 0, ActionMCP::Logging::Level.coerce("debug")
    assert_equal 3, ActionMCP::Logging::Level.coerce("warning")
    assert_equal 7, ActionMCP::Logging::Level.coerce("emergency")
  end

  test "coerces symbol levels to integers" do
    assert_equal 1, ActionMCP::Logging::Level.coerce(:info)
    assert_equal 4, ActionMCP::Logging::Level.coerce(:error)
  end

  test "passes through valid integer levels" do
    assert_equal 2, ActionMCP::Logging::Level.coerce(2)
    assert_equal 5, ActionMCP::Logging::Level.coerce(5)
  end

  test "raises ArgumentError for invalid levels" do
    assert_raises(ArgumentError) { ActionMCP::Logging::Level.coerce("invalid") }
    assert_raises(ArgumentError) { ActionMCP::Logging::Level.coerce(:invalid) }
    assert_raises(ArgumentError) { ActionMCP::Logging::Level.coerce(8) }
    assert_raises(ArgumentError) { ActionMCP::Logging::Level.coerce(nil) }
  end

  test "converts integer levels back to symbol names" do
    assert_equal :debug, ActionMCP::Logging::Level.name_for(0)
    assert_equal :warning, ActionMCP::Logging::Level.name_for(3)
    assert_equal :emergency, ActionMCP::Logging::Level.name_for(7)
  end

  test "raises ArgumentError for invalid integer levels in name_for" do
    assert_raises(ArgumentError) { ActionMCP::Logging::Level.name_for(8) }
    assert_raises(ArgumentError) { ActionMCP::Logging::Level.name_for(-1) }
  end

  test "returns all valid level names" do
    expected = [ :debug, :info, :notice, :warning, :error, :critical, :alert, :emergency ]
    assert_equal expected, ActionMCP::Logging::Level.all_levels
  end

  test "correctly compares severity levels" do
    # Same level
    assert ActionMCP::Logging::Level.more_severe_or_equal?(:warning, :warning)
    assert ActionMCP::Logging::Level.more_severe_or_equal?(3, 3)

    # More severe
    assert ActionMCP::Logging::Level.more_severe_or_equal?(:error, :warning)
    assert ActionMCP::Logging::Level.more_severe_or_equal?(4, 3)
    assert ActionMCP::Logging::Level.more_severe_or_equal?(:emergency, :debug)

    # Less severe
    assert_not ActionMCP::Logging::Level.more_severe_or_equal?(:debug, :info)
    assert_not ActionMCP::Logging::Level.more_severe_or_equal?(0, 1)
    assert_not ActionMCP::Logging::Level.more_severe_or_equal?(:warning, :error)
  end

  test "handles mixed types in severity comparison" do
    assert ActionMCP::Logging::Level.more_severe_or_equal?("error", :warning)
    assert ActionMCP::Logging::Level.more_severe_or_equal?(4, "warning")
    assert ActionMCP::Logging::Level.more_severe_or_equal?(:error, 3)
  end
end
