# frozen_string_literal: true

module ActionMCP
  module Logging
    # MCP Logger that sends notifications/message to the MCP client
    class Logger
      attr_reader :name, :session, :state

      # Initialize a new MCP logger
      # @param name [String, nil] Optional logger name
      # @param session [ActionMCP::Session] The MCP session for transport
      # @param state [ActionMCP::Logging::State] The global logging state
      def initialize(name: nil, session:, state:)
        @name = name
        @session = session
        @state = state
      end

      # Log a debug message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def debug(message = nil, data: nil, &block)
        log(:debug, message, data: data, &block)
      end

      # Log an info message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def info(message = nil, data: nil, &block)
        log(:info, message, data: data, &block)
      end

      # Log a notice message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def notice(message = nil, data: nil, &block)
        log(:notice, message, data: data, &block)
      end

      # Log a warning message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def warning(message = nil, data: nil, &block)
        log(:warning, message, data: data, &block)
      end
      alias_method :warn, :warning

      # Log an error message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def error(message = nil, data: nil, &block)
        log(:error, message, data: data, &block)
      end

      # Log a critical message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def critical(message = nil, data: nil, &block)
        log(:critical, message, data: data, &block)
      end

      # Log an alert message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def alert(message = nil, data: nil, &block)
        log(:alert, message, data: data, &block)
      end

      # Log an emergency message
      # @param message [String, nil] The message (if no block given)
      # @param data [Object] Additional structured data
      # @yield Block that returns the message (evaluated only if logging)
      # @return [void]
      def emergency(message = nil, data: nil, &block)
        log(:emergency, message, data: data, &block)
      end

      # Check if debug level is enabled
      # @return [Boolean] true if debug messages will be logged
      def debug?
        state.should_log?(:debug)
      end

      # Check if info level is enabled
      # @return [Boolean] true if info messages will be logged
      def info?
        state.should_log?(:info)
      end

      # Check if notice level is enabled
      # @return [Boolean] true if notice messages will be logged
      def notice?
        state.should_log?(:notice)
      end

      # Check if warning level is enabled
      # @return [Boolean] true if warning messages will be logged
      def warning?
        state.should_log?(:warning)
      end
      alias_method :warn?, :warning?

      # Check if error level is enabled
      # @return [Boolean] true if error messages will be logged
      def error?
        state.should_log?(:error)
      end

      # Check if critical level is enabled
      # @return [Boolean] true if critical messages will be logged
      def critical?
        state.should_log?(:critical)
      end

      # Check if alert level is enabled
      # @return [Boolean] true if alert messages will be logged
      def alert?
        state.should_log?(:alert)
      end

      # Check if emergency level is enabled
      # @return [Boolean] true if emergency messages will be logged
      def emergency?
        state.should_log?(:emergency)
      end

      private

      # Core logging method
      # @param level [Symbol] The log level
      # @param message [String, nil] The message
      # @param data [Object] Additional data
      # @yield Block that returns message
      # @return [void]
      def log(level, message = nil, data: nil, &block)
        return unless state.should_log?(level)

        # Evaluate message from block if provided
        final_message = if block_given?
                          yield
        else
                          message
        end

        # Send MCP notification
        send_mcp_notification(level, final_message, data)
      end

      # Send notifications/message to MCP client
      # @param level [Symbol] The log level
      # @param message [String] The message
      # @param data [Object] Additional data
      # @return [void]
      def send_mcp_notification(level, message, data)
        params = {
          level: level.to_s,
          data: build_log_data(message, data)
        }

        # Add logger name if present
        params[:logger] = name if name

        # Send via session's messaging service
        session.messaging_service.send_notification("notifications/message", params)
      rescue StandardError => e
        # Fallback to Rails logger if MCP transport fails
        Rails.logger.error "Failed to send MCP log notification: #{e.message}"
      end

      # Build the data payload for the log message
      # @param message [String] The primary message
      # @param additional_data [Object] Additional structured data
      # @return [Object] The data to send in the notification
      def build_log_data(message, additional_data)
        case additional_data
        when nil
          message
        when Hash
          if message
            { message: message }.merge(additional_data)
          else
            additional_data
          end
        else
          if message
            { message: message, data: additional_data }
          else
            additional_data
          end
        end
      end
    end
  end
end
