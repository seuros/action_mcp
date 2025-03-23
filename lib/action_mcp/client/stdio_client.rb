# frozen_string_literal: true

module ActionMCP
  class Client
    # MCP client using Standard I/O (STDIO) transport
    class StdioClient < Client
      # Initialize a STDIO client
      # @param command [String] The command to execute
      # @param logger [Logger] The logger to use
      def initialize(command, logger: Logger.new($stdout))
        super(logger: logger)
        @command = command
        @transport = Transport::StdioClient.new(command, logger: logger)
        @type = :stdio

        # Set up callbacks after transport is initialized
        setup_callbacks
      end

      protected

      def start_transport
        @transport.start
        # For STDIO, we'll send the capabilities from the connect method
        # after this method completes and @connected is set to true
      end

      private

      def setup_callbacks
        @transport.on_message do |message|
          # Check if this is a response to our initialize request
          @transport.handle_initialize_response(message) if message&.id && message.id == @initialize_request_id

          @message_callback&.call(message)
        end

        @transport.on_error do |error|
          @error_callback&.call(error)
        end
      end
    end
  end
end
