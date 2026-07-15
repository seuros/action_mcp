# frozen_string_literal: true

require "active_support/tagged_logging"
require "active_support/logger"
require "logger"

module ActionMCP
  # Global MCP logging interface
  module Logging
    SESSION_LEVEL_KEY = "action_mcp_logging_level"

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

      # Return the minimum log level negotiated for a session, falling back to
      # the configured server default until the client sends logging/setLevel.
      def level_for(session)
        session_data = session.respond_to?(:session_data) && session.session_data
        stored_level = session_data[SESSION_LEVEL_KEY] if session_data.is_a?(Hash)
        Level.name_for(Level.coerce(stored_level || level))
      end

      def set_level_for(session, new_level)
        normalized_level = Level.name_for(Level.coerce(new_level))
        session_data = session.session_data.is_a?(Hash) ? session.session_data.deep_dup : {}
        session_data[SESSION_LEVEL_KEY] = normalized_level.to_s

        if session.respond_to?(:update!)
          session.update!(session_data: session_data)
        else
          session.session_data = session_data
          session.save! if session.respond_to?(:save!)
        end

        normalized_level
      end

      def supported_by?(session)
        return false unless session&.respond_to?(:server_capabilities)

        capabilities = session.server_capabilities
        capabilities.is_a?(Hash) &&
          (capabilities.key?("logging") || capabilities.key?(:logging))
      end

      # Create a logger for the given session
      # @param name [String, nil] Optional logger name
      # @param session [ActionMCP::Session] The MCP session
      # @return [ActionMCP::Logging::Logger, ActionMCP::Logging::NullLogger] logger instance
      def logger(name: nil, session:)
        if enabled? && supported_by?(session)
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
