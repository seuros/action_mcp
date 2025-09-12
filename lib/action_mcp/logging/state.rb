# frozen_string_literal: true

require "concurrent"

module ActionMCP
  module Logging
    # Thread-safe global state for MCP logging
    class State
      # Initialize with default values
      def initialize
        @enabled = Concurrent::AtomicBoolean.new(false)
        @global_level = Concurrent::AtomicFixnum.new(Level::LEVELS[:warning])
      end

      # Check if logging is enabled
      # @return [Boolean] true if enabled, false otherwise
      def enabled?
        @enabled.value
      end

      # Enable logging
      # @return [Boolean] true (new value)
      def enable!
        @enabled.make_true
      end

      # Disable logging
      # @return [Boolean] false (new value)
      def disable!
        @enabled.make_false
      end

      # Set enabled state
      # @param value [Boolean] true to enable, false to disable
      # @return [Boolean] the new value
      def enabled=(value)
        if value
          enable!
        else
          disable!
        end
      end

      # Get current minimum log level as integer
      # @return [Integer] the current level (0-7)
      def level
        @global_level.value
      end

      # Get current minimum log level as symbol
      # @return [Symbol] the current level symbol
      def level_symbol
        Level.name_for(@global_level.value)
      end

      # Set minimum log level
      # @param new_level [String, Symbol, Integer] the new level
      # @return [Integer] the new level as integer
      def level=(new_level)
        level_int = Level.coerce(new_level)
        @global_level.value = level_int
        level_int
      end

      # Check if a message at the given level should be logged
      # @param message_level [String, Symbol, Integer] the message level
      # @return [Boolean] true if should be logged, false otherwise
      def should_log?(message_level)
        return false unless enabled?

        message_level_int = Level.coerce(message_level)
        message_level_int >= @global_level.value
      end

      # Reset to initial state (for testing)
      # @return [void]
      def reset!
        disable!
        self.level = :warning
      end
    end
  end
end
