# frozen_string_literal: true

module ActionMCP
  module Client
    # Base client class containing common MCP functionality
    class Base
      # Include all transport protocol modules
      include Messaging
      include Tools
      include Prompts
      include Resources
      include Roots
      include Logging

      attr_reader :logger, :type,
                  :connection_error,
                  :server_capabilities, :session,
                  :catalog, :blueprint,
                  :prompt_book, :toolbox
      attr_writer :server
      delegate :initialized?, to: :session

      def initialize(logger: ActionMCP.logger)
        @logger = logger
        @connected = false
        @session = Session.from_client.new(
          protocol_version: PROTOCOL_VERSION,
          client_info: client_info,
          client_capabilities: client_capabilities
        )
        @initialize_request_id = @session.id
        @server_capabilities = nil
        @message_callback = nil
        @error_callback = nil
        @connection_error = nil
        @initialized = false

        # Resource objects
        @catalog = Catalog.new([], self)
        # Resource template objects
        @blueprint = Blueprint.new([], self)
        # Prompt objects
        @prompt_book = PromptBook.new([], self)
        # Tool objects
        @toolbox = Toolbox.new([], self)
      end

      def connected?
        @connected
      end

      # Connect to the MCP server, if something went wrong at initialization
      def connect
        return true if @connected

        begin
          log_info("Connecting to MCP server...")
          @connection_error = nil

          # Start transport with proper error handling
          success = start_transport

          unless success
            log_error("Failed to establish connection to MCP server")
            return false
          end

          @connected = true
          log_info("Connected to MCP server")
          session.save

          # Create handler only if it doesn't exist yet
          @json_rpc_handler ||= JsonRpcHandler.new(session)

          # Clear any existing message callback and set a new one
          @message_callback = lambda do |response|
            @json_rpc_handler.call(response)
          end

          true
        rescue StandardError => e
          @connection_error = e.message
          log_error("Failed to connect to MCP server: #{e.message}")
          @error_callback&.call(e)
          false
        end
      end

      # Disconnect from the MCP server
      def disconnect
        return true unless @connected

        begin
          stop_transport
          @connected = false
          log_info("Disconnected from MCP server")
          true
        rescue StandardError => e
          log_error("Error disconnecting from MCP server: #{e.message}")
          @error_callback&.call(e)
          false
        end
      end

      # Set a callback for incoming messages
      def on_message(&block)
        @message_callback = block
      end

      # Set a callback for errors
      def on_error(&block)
        @error_callback = block
      end

      # Send a request to the MCP server
      def write_message(payload)
        unless @connected
          log_error("Cannot send request - not connected")
          return false
        end

        begin
          data = payload.to_json unless payload.is_a?(String)
          send_message(data)
          true
        rescue StandardError => e
          log_error("Failed to send request: #{e.message}")
          @error_callback&.call(e)
          false
        end
      end

      # Methods to be implemented by subclasses
      def start_transport
        raise NotImplementedError, "#{self.class} must implement #start_transport"
      end

      def stop_transport
        raise NotImplementedError, "#{self.class} must implement #stop_transport"
      end

      def send_message(json)
        raise NotImplementedError, "#{self.class} must implement #send_message"
      end

      def ready?
        raise NotImplementedError, "#{self.class} must implement #ready?"
      end

      protected

      def handle_raw_message(raw)
        log_debug("\e[31m<-- #{raw}\e[0m")
        begin
          msg_hash = MultiJson.load(raw)
          response = nil

          if msg_hash.key?("jsonrpc")
            response = if msg_hash.key?("id")
                         JsonRpc::Response.new(**msg_hash.slice("id", "result", "error").symbolize_keys)
            else
                         JsonRpc::Notification.new(**msg_hash.slice("method", "params").symbolize_keys)
            end
          end

          # Check if this is a response to our initialize request
          if response && response.id == @initialize_request_id
            handle_initialize_response(response)
          elsif response
            @message_callback&.call(raw)
          end
        rescue MultiJson::ParseError => e
          log_error("JSON parse error: #{e} (raw: #{raw})")
          @error_callback&.call(e)
        rescue StandardError => e
          log_error("Error handling message: #{e} (raw: #{raw})")
          @error_callback&.call(e)
        end
      end

      def handle_initialize_response(response)
        return if initialized?

        if response.result
          self.server = Client::Server.new(response.result)
          send_initialized_notification
        else
          log_error("Server initialization failed: #{response.error}")
          @error_callback&.call(StandardError.new("Initialization failed: #{response.error}"))
        end
      end

      def send_initial_capabilities
        log_info("Sending client capabilities")

        request = JsonRpc::Request.new(
          id: @initialize_request_id,
          method: "initialize",
          params: {
            protocolVersion: session.protocol_version,
            capabilities: session.client_capabilities,
            clientInfo: session.client_info
          }
        )

        send_message(request.to_json)
      end

      def send_initialized_notification
        notification = JsonRpc::Notification.new(
          method: "notifications/initialized"
        )

        log_info("Sending initialized notification")
        session.initialize!
        send_message(notification.to_json)
      end

      def client_capabilities
        {
          # Base client capabilities can be defined here
          # TODO
        }
      end

      def user_agent
        "ActionMCP-Client"
      end

      def client_info
        {
          name: user_agent,
          version: ActionMCP.gem_version.to_s
        }
      end

      def log_debug(message)
        logger.debug("[ActionMCP::#{self.class.name.split('::').last}] #{message}")
      end

      def log_info(message)
        logger.info("[ActionMCP::#{self.class.name.split('::').last}] #{message}")
      end

      def log_error(message)
        logger.error("[ActionMCP::#{self.class.name.split('::').last}] #{message}")
      end
    end
  end
end
