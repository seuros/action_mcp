# frozen_string_literal: true

module ActionMCP
  module Logging
    # RFC 5424 log levels for MCP logging
    # @see https://datatracker.ietf.org/doc/html/rfc5424#section-6.2.1
    class Level
      # Log levels in order of severity (ascending)
      LEVELS = {
        debug: 0,
        info: 1,
        notice: 2,
        warning: 3,
        error: 4,
        critical: 5,
        alert: 6,
        emergency: 7
      }.freeze

      # Reverse mapping for converting integers back to symbols
      LEVEL_NAMES = LEVELS.invert.freeze

      class << self
        # Check if a level is valid
        # @param level [String, Symbol, Integer] The level to check
        # @return [Boolean] true if valid, false otherwise
        def valid?(level)
          case level
          when String, Symbol
            LEVELS.key?(level.to_sym)
          when Integer
            LEVEL_NAMES.key?(level)
          else
            false
          end
        end

        # Coerce a level to its integer value
        # @param level [String, Symbol, Integer] The level to coerce
        # @return [Integer] The integer severity value
        # @raise [ArgumentError] if level is invalid
        def coerce(level)
          case level
          when String, Symbol
            symbol_level = level.to_sym
            LEVELS.fetch(symbol_level) do
              raise ArgumentError, "Invalid log level: #{level}. Valid levels: #{LEVELS.keys.join(', ')}"
            end
          when Integer
            unless LEVEL_NAMES.key?(level)
              raise ArgumentError, "Invalid log level: #{level}. Valid levels: 0-7"
            end
            level
          else
            raise ArgumentError, "Invalid log level type: #{level.class}. Expected String, Symbol, or Integer"
          end
        end

        # Convert integer level back to symbol
        # @param level_int [Integer] The integer level
        # @return [Symbol] The symbol name
        def name_for(level_int)
          LEVEL_NAMES.fetch(level_int) do
            raise ArgumentError, "Invalid log level integer: #{level_int}"
          end
        end

        # Get all valid level names as symbols
        # @return [Array<Symbol>] Array of level symbols
        def all_levels
          LEVELS.keys
        end

        # Check if level_a is more severe than level_b
        # @param level_a [String, Symbol, Integer] First level
        # @param level_b [String, Symbol, Integer] Second level
        # @return [Boolean] true if level_a >= level_b in severity
        def more_severe_or_equal?(level_a, level_b)
          coerce(level_a) >= coerce(level_b)
        end
      end
    end
  end
end
