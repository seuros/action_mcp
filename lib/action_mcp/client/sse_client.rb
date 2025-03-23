# frozen_string_literal: true

module ActionMCP
  class Client
    # MCP client using Server-Sent Events (SSE) transport
    class SSEClient < Client
      # Initialize an SSE client
      # @param endpoint [String] The SSE endpoint URL
      # @param logger [Logger] The logger to use
      def initialize(endpoint, logger: Logger.new($stdout))
        super(logger: logger)
        @endpoint = endpoint
        @transport = Transport::SSEClient.new(endpoint, logger: logger)
        @type = :sse

        # Set up callbacks after transport is initialized
        setup_callbacks
      end

      protected

      def start_transport
        @transport.start(@initialize_request_id)
        true
      rescue Transport::SSEClient::ConnectionError => e
        @connection_error = e.message
        @error_callback&.call(e)
        false
      rescue StandardError => e
        @connection_error = e.message
        @error_callback&.call(e)
        false
      end

      private

      def setup_callbacks
        @transport.on_message do |message|
          # Check if this is a response to our initialize request
          puts @initialize_request_id
          if message&.id == @initialize_request_id
            @transport.handle_initialize_response(message)
          else
            puts "\e[32mCalling message callback\e[0m"
            @message_callback&.call(message)
          end
        end

        @transport.on_error do |error|
          @error_callback&.call(error)
        end
      end
    end
  end
end
