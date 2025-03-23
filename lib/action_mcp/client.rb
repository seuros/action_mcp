# frozen_string_literal: true

module ActionMCP
  # Create a client appropriate for the given endpoint
  # @param endpoint [String] The endpoint to connect to (URL or command)
  # @param logger [Logger] The logger to use
  # @return [Client] An SSEClient or StdioClient depending on the endpoint
  # @example
  #  client = ActionMCP.create_client("http://127.0.0.1:3001/action_mcp")
  #  client.connect
  def self.create_client(endpoint, logger: Logger.new($stdout))
    if endpoint =~ %r{\Ahttps?://}
      logger.info("Creating SSE client for endpoint: #{endpoint}")
      Client::SSEClient.new(endpoint, logger: logger)
    else
      logger.info("Creating STDIO client for command: #{endpoint}")
      Client::StdioClient.new(endpoint, logger: logger)
    end
  end

  # Base client class for MCP protocol
  class Client
    attr_reader :logger, :capabilities, :type, :connection_error

    def initialize(logger: Logger.new($stdout))
      @logger = logger
      @connected = false
      @initialize_request_id = SecureRandom.uuid_v7
      @server_capabilities = nil
      @message_callback = nil
      @error_callback = nil
      @connection_error = nil
    end

    def connect
      return true if @connected

      begin
        logger.info("Connecting to MCP server...")
        @connection_error = nil

        # Start transport with proper error handling
        success = start_transport

        unless success
          logger.error("Failed to establish connection to MCP server")
          return false
        end

        @connected = true
        logger.info("Connected to MCP server")
        true
      rescue StandardError => e
        @connection_error = e.message
        logger.error("Failed to connect to MCP server: #{e.message}")
        false
      end
    end

    # Disconnect from the MCP server
    # @return [Boolean] true if disconnection was successful
    def disconnect
      return true unless @connected

      begin
        stop_transport
        @connected = false
        logger.info("Disconnected from MCP server")
        true
      rescue StandardError => e
        logger.error("Error disconnecting from MCP server: #{e.message}")
        false
      end
    end

    # Send a request to the MCP server
    # @param payload [Hash, String] The request payload
    # @return [Boolean] true if the request was sent successfully
    def send_request(payload)
      unless @connected
        logger.error("Cannot send request - not connected")
        return false
      end

      begin
        json = prepare_payload(payload)
        send_message(json)
        true
      rescue StandardError => e
        logger.error("Failed to send request: #{e.message}")
        false
      end
    end

    # Check if the client is ready to send requests
    # @return [Boolean] true if the client is connected and ready
    def ready?
      @connected && transport_ready?
    end

    # Set a callback for incoming messages
    # @yield [message] Called when a message is received
    # @yieldparam message The received message
    def on_message(&block)
      @message_callback = block
    end

    # Set a callback for errors
    # @yield [error] Called when an error occurs
    # @yieldparam error The error that occurred
    def on_error(&block)
      @error_callback = block
    end

    # Get the server capabilities
    # @return [Hash, nil] The server capabilities, or nil if not connected
    attr_reader :server_capabilities

    protected

    # Start the transport - implemented by subclasses
    def start_transport
      raise NotImplementedError, "Subclasses must implement start_transport"
    end

    # Stop the transport
    def stop_transport
      @transport.stop
    end

    # Send a message through the transport
    def send_message(json)
      @transport.send_message(json)
    end

    # Check if the transport is ready
    def transport_ready?
      @transport.ready?
    end

    private

    # Prepare a payload for sending
    # @param payload [Hash, String] The payload to prepare
    # @return [String] The JSON-encoded payload
    def prepare_payload(payload)
      case payload
      when String
        # Assume it's already JSON
        payload
      else
        # Try to convert to JSON
        MultiJson.dump(payload)
      end
    end
  end
end
