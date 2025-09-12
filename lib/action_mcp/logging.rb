# frozen_string_literal: true

require "active_support/tagged_logging"
require "active_support/logger"
require "logger"

module ActionMCP
  # Global MCP logging interface
  module Logging
    class << self
      # Get the global logging state
      # @return [ActionMCP::Logging::State] The global state
      def state
        @state ||= State.new
      end

      # Reset the global state (for testing)
      # @return [void]
      def reset!
        @state = State.new
      end

      # Check if logging is enabled
      # @return [Boolean] true if enabled
      def enabled?
        ActionMCP.configuration.logging_enabled && state.enabled?
      end

      # Enable MCP logging
      # @return [Boolean] true
      def enable!
        ActionMCP.configuration.logging_enabled = true
        state.enable!
      end

      # Disable MCP logging
      # @return [Boolean] false
      def disable!
        state.disable!
      end

      # Get the current minimum log level
      # @return [Symbol] current level
      def level
        state.level_symbol
      end

      # Set the minimum log level
      # @param new_level [String, Symbol, Integer] the new level
      # @return [Symbol] the new level as symbol
      def level=(new_level)
        state.level = new_level
        state.level_symbol
      end
      alias_method :set_level, :level=

      # Create a logger for the given session
      # @param name [String, nil] Optional logger name
      # @param session [ActionMCP::Session] The MCP session
      # @return [ActionMCP::Logging::Logger, ActionMCP::Logging::NullLogger] logger instance
      def logger(name: nil, session:)
        if enabled?
          Logger.new(name: name, session: session, state: state)
        else
          NullLogger.new
        end
      end

      # Convenience method to get a logger for the current session context
      # @param name [String, nil] Optional logger name
      # @param execution_context [Hash] Context containing session
      # @return [ActionMCP::Logging::Logger, ActionMCP::Logging::NullLogger] logger instance
      def logger_for_context(name: nil, execution_context:)
        session = execution_context[:session]
        return NullLogger.new unless session

        logger(name: name, session: session)
      end
    end

    # Initialize logging state based on configuration
    def self.initialize_from_config!
      # Always set the level from configuration
      state.level = ActionMCP.configuration.logging_level

      if ActionMCP.configuration.logging_enabled
        state.enable!
      else
        state.disable!
      end
    end
  end
end
