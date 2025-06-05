# frozen_string_literal: true

module ActionMCP
  module Client
    # Base transport interface for MCP client connections
    module Transport
      # Called when transport should establish connection
      def connect
        raise NotImplementedError, "#{self.class} must implement #connect"
      end

      # Called when transport should close connection
      def disconnect
        raise NotImplementedError, "#{self.class} must implement #disconnect"
      end

      # Send a message through the transport
      def send_message(message)
        raise NotImplementedError, "#{self.class} must implement #send_message"
      end

      # Check if transport is ready to send/receive
      def ready?
        raise NotImplementedError, "#{self.class} must implement #ready?"
      end

      # Check if transport is connected
      def connected?
        raise NotImplementedError, "#{self.class} must implement #connected?"
      end

      # Set callback for received messages
      def on_message(&block)
        @message_callback = block
      end

      # Set callback for errors
      def on_error(&block)
        @error_callback = block
      end

      # Set callback for connection events
      def on_connect(&block)
        @connect_callback = block
      end

      # Set callback for disconnection events
      def on_disconnect(&block)
        @disconnect_callback = block
      end

      protected

      def handle_message(message)
        @message_callback&.call(message)
      end

      def handle_error(error)
        @error_callback&.call(error)
      end

      def handle_connect
        @connect_callback&.call
      end

      def handle_disconnect
        @disconnect_callback&.call
      end
    end

    # Base class for transport implementations
    class TransportBase
      include Transport
      include Logging

      attr_reader :url, :options, :session_store

      def initialize(url, session_store:, logger: ActionMCP.logger, **options)
        @url = url
        @session_store = session_store
        @logger = logger
        @options = options
        @connected = false
        @ready = false
      end

      def connected?
        @connected
      end

      def ready?
        @ready
      end

      protected

      def set_connected(state)
        @connected = state
        state ? handle_connect : handle_disconnect
      end

      def set_ready(state)
        @ready = state
      end
    end
  end
end
