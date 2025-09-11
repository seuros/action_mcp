# frozen_string_literal: true

module ActionMCP
  module Logging
    # Mixin to provide easy MCP logging access for tools, prompts, and resources
    module Mixin
      extend ActiveSupport::Concern

      # Get the MCP logger for this instance
      # @return [ActionMCP::Logging::Logger, ActionMCP::Logging::NullLogger] logger instance
      def mcp_logger
        @mcp_logger ||= ActionMCP::Logging.logger_for_context(
          name: logger_name,
          execution_context: execution_context
        )
      end

      # Log a debug message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def mcp_debug(message = nil, data: nil, &block)
        mcp_logger.debug(message, data: data, &block)
      end

      # Log an info message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def mcp_info(message = nil, data: nil, &block)
        mcp_logger.info(message, data: data, &block)
      end

      # Log a notice message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def mcp_notice(message = nil, data: nil, &block)
        mcp_logger.notice(message, data: data, &block)
      end

      # Log a warning message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def mcp_warning(message = nil, data: nil, &block)
        mcp_logger.warning(message, data: data, &block)
      end
      alias_method :mcp_warn, :mcp_warning

      # Log an error message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def mcp_error(message = nil, data: nil, &block)
        mcp_logger.error(message, data: data, &block)
      end

      # Log a critical message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def mcp_critical(message = nil, data: nil, &block)
        mcp_logger.critical(message, data: data, &block)
      end

      # Log an alert message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def mcp_alert(message = nil, data: nil, &block)
        mcp_logger.alert(message, data: data, &block)
      end

      # Log an emergency message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def mcp_emergency(message = nil, data: nil, &block)
        mcp_logger.emergency(message, data: data, &block)
      end

      # Check if debug level is enabled
      # @return [Boolean] true if debug messages will be logged
      def mcp_debug?
        mcp_logger.debug?
      end

      # Check if info level is enabled
      # @return [Boolean] true if info messages will be logged
      def mcp_info?
        mcp_logger.info?
      end

      # Check if notice level is enabled
      # @return [Boolean] true if notice messages will be logged
      def mcp_notice?
        mcp_logger.notice?
      end

      # Check if warning level is enabled
      # @return [Boolean] true if warning messages will be logged
      def mcp_warning?
        mcp_logger.warning?
      end
      alias_method :mcp_warn?, :mcp_warning?

      # Check if error level is enabled
      # @return [Boolean] true if error messages will be logged
      def mcp_error?
        mcp_logger.error?
      end

      # Check if critical level is enabled
      # @return [Boolean] true if critical messages will be logged
      def mcp_critical?
        mcp_logger.critical?
      end

      # Check if alert level is enabled
      # @return [Boolean] true if alert messages will be logged
      def mcp_alert?
        mcp_logger.alert?
      end

      # Check if emergency level is enabled
      # @return [Boolean] true if emergency messages will be logged
      def mcp_emergency?
        mcp_logger.emergency?
      end

      private

      # Generate logger name from class name
      # @return [String] the logger name
      def logger_name
        self.class.name&.underscore || "unknown"
      end
    end
  end
end
