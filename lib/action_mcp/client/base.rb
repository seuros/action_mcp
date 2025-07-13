# frozen_string_literal: true

require_relative "transport"

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
      include Elicitation
      include Logging

      attr_reader :logger, :transport,
                  :connection_error, :server,
                  :server_capabilities, :session,
                  :catalog, :blueprint,
                  :prompt_book, :toolbox

      delegate :connected?, :ready?, to: :transport

      def initialize(transport:, logger: ActionMCP.logger, protocol_version: nil, **options)
        @logger = logger
        @transport = transport
        @session = nil  # Session will be created/loaded based on server response
        @session_id = options[:session_id]  # Optional session ID for resumption
        @protocol_version = protocol_version || ActionMCP::DEFAULT_PROTOCOL_VERSION
        @server_capabilities = nil
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

        setup_transport_callbacks
      end

      # Connect to the MCP server
      def connect
        return true if connected?

        begin
          log_debug("Connecting to MCP server via #{transport.class.name}...")
          @connection_error = nil

          success = @transport.connect
          unless success
            log_error("Failed to establish transport connection")
            return false
          end

          log_debug("Connected to MCP server")
          true
        rescue StandardError => e
          @connection_error = e.message
          log_error("Failed to connect to MCP server: #{e.message}")
          false
        end
      end

      # Disconnect from the MCP server
      def disconnect
        return true unless connected?

        begin
          @transport.disconnect
          log_debug("Disconnected from MCP server")
          true
        rescue StandardError => e
          log_error("Error disconnecting from MCP server: #{e.message}")
          false
        end
      end

      # Send a request to the MCP server
      def write_message(payload)
        unless ready?
          log_error("Cannot send request - transport not ready")
          return false
        end

        begin
          # Only write to session if it exists (after initialization)
          session.write(payload) if session
          data = payload.to_json unless payload.is_a?(String)
          @transport.send_message(data)
          true
        rescue StandardError => e
          log_error("Failed to send request: #{e.message}")
          false
        end
      end

      def server=(server)
        @server = if server.is_a?(Client::Server)
                    server
        else
                    Client::Server.new(server)
        end

        # Only update session if it exists
        if @session
          @session.server_capabilities = server.capabilities
          @session.server_info = server.server_info
          @session.save
        end
      end

      def initialized?
        @initialized && @session&.initialized?
      end

      def inspect
        session_info = @session ? "session: #{@session.id}" : "session: none"
        "#<#{self.class.name} transport: #{transport.class.name}, server: #{server}, client_name: #{client_info[:name]}, client_version: #{client_info[:version]}, capabilities: #{client_capabilities}, connected: #{connected?}, initialized: #{initialized?}, #{session_info}>"
      end

      protected

      def setup_transport_callbacks
        # Create JSON-RPC handler
        @json_rpc_handler = JsonRpcHandler.new(session, self)

        # Set up transport callbacks
        @transport.on_message do |message|
          handle_raw_message(message)
        end

        @transport.on_error do |error|
          handle_transport_error(error)
        end

        @transport.on_connect do
          handle_transport_connect
        end

        @transport.on_disconnect do
          handle_transport_disconnect
        end
      end

      def handle_raw_message(raw)
        @json_rpc_handler.call(raw)
      rescue MultiJson::ParseError => e
        log_error("JSON parse error: #{e} (raw: #{raw})")
      rescue StandardError => e
        log_error("Error handling message: #{e} (raw: #{raw})")
      end

      def handle_transport_error(error)
        @connection_error = error.message
        log_error("Transport error: #{error.message}")
      end

      def handle_transport_connect
        log_debug("Transport connected")
        # Send initial capabilities after connection
        send_initial_capabilities
      end

      def handle_transport_disconnect
        log_debug("Transport disconnected")
      end

      def send_initial_capabilities
        log_debug("Sending client capabilities")

        # If we have a session_id, we're trying to resume
        if @session_id
          log_debug("Attempting to resume session: #{@session_id}")
        end

        params = {
          protocolVersion: @protocol_version,
          capabilities: client_capabilities,
          clientInfo: client_info
        }

        # Include session_id if we're trying to resume
        params[:sessionId] = @session_id if @session_id

        # Use a unique request ID (not session ID since we don't have one yet)
        request_id = SecureRandom.uuid
        send_jsonrpc_request("initialize", params: params, id: request_id)
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
