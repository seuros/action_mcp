# frozen_string_literal: true

require_relative "client/transport"
require_relative "client/session_store"
require_relative "client/streamable_http_transport"
require_relative "client/streamable_client"
require_relative "client/oauth_client_provider"

module ActionMCP
  module Client
  end

  # Main MCP client class following the MCP specification
  # This class provides the primary interface for interacting with MCP servers
  class MCPClient
    PROTOCOL_VERSION = "2025-03-26"
    SUPPORTED_PROTOCOL_VERSIONS = [ PROTOCOL_VERISON ].freeze

    attr_reader :logger, :transport, :session_id,
                :server_capabilities, :server_info, :instructions,
                :capabilities

    def initialize(transport:, logger: Logger.new($stdout), session_id: nil, capabilities: {}, **options)
      @logger = logger
      @transport = transport
      @session_id = session_id
      @capabilities = capabilities
      @server_capabilities = nil
      @server_info = nil
      @instructions = nil
      @connected = false
      @initialized = false
      @options = options

      setup_transport_callbacks
    end

    # Connect to the MCP server and initialize the protocol
    def connect(options = {})
      return self if connected?

      begin
        log_debug("Connecting to MCP server...")
        if @transport.respond_to?(:start)
          @transport.start
        else
          @transport.connect
        end

        # If transport has sessionId set, we're resuming - skip initialization
        return self if @transport.respond_to?(:session_id) && @transport.session_id

        # Initialize the protocol
        initialize_protocol(options)
        self
      rescue => error
        log_error("Failed to connect: #{error.message}")
        disconnect
        raise
      end
    end

    # Disconnect from the MCP server
    def disconnect
      return self unless connected?

      begin
        if @transport.respond_to?(:close)
          @transport.close
        elsif @transport.respond_to?(:disconnect)
          @transport.disconnect
        end
        @connected = false
        @initialized = false
        log_debug("Disconnected from MCP server")
      rescue => error
        log_error("Error during disconnect: #{error.message}")
      ensure
        @connected = false
        @initialized = false
      end
      self
    end

    # Check if connected to the server
    def connected?
      @transport&.connected?
    end

    # Check if protocol initialization is complete
    def initialized?
      @initialized
    end

    # Send a ping request to the server
    def ping(options = {})
      request({ method: "ping" }, options)
    end

    # List available tools from the server
    def list_tools(params = {}, options = {})
      assert_capability(:tools, "tools/list")
      request({ method: "tools/list", params: params }, options)
    end

    # Call a tool on the server
    def call_tool(name:, arguments: {}, **options)
      assert_capability(:tools, "tools/call")
      params = { name: name, arguments: arguments }
      request({ method: "tools/call", params: params }, options)
    end

    # List available prompts from the server
    def list_prompts(params = {}, options = {})
      assert_capability(:prompts, "prompts/list")
      request({ method: "prompts/list", params: params }, options)
    end

    # Get a prompt from the server
    def get_prompt(name:, arguments: {}, **options)
      assert_capability(:prompts, "prompts/get")
      params = { name: name, arguments: arguments }
      request({ method: "prompts/get", params: params }, options)
    end

    # List available resources from the server
    def list_resources(params = {}, options = {})
      assert_capability(:resources, "resources/list")
      request({ method: "resources/list", params: params }, options)
    end

    # List available resource templates from the server
    def list_resource_templates(params = {}, options = {})
      assert_capability(:resources, "resources/templates/list")
      request({ method: "resources/templates/list", params: params }, options)
    end

    # Read a resource from the server
    def read_resource(uri:, **options)
      assert_capability(:resources, "resources/read")
      params = { uri: uri }
      request({ method: "resources/read", params: params }, options)
    end

    # Subscribe to resource changes
    def subscribe_resource(uri:, **options)
      assert_capability(:resources, "resources/subscribe")
      assert_resource_capability(:subscribe, "resources/subscribe")
      params = { uri: uri }
      request({ method: "resources/subscribe", params: params }, options)
    end

    # Unsubscribe from resource changes
    def unsubscribe_resource(uri:, **options)
      assert_capability(:resources, "resources/unsubscribe")
      params = { uri: uri }
      request({ method: "resources/unsubscribe", params: params }, options)
    end

    # Set logging level on the server
    def set_logging_level(level:, **options)
      assert_capability(:logging, "logging/setLevel")
      params = { level: level }
      request({ method: "logging/setLevel", params: params }, options)
    end

    # Complete text/code using server's completion capabilities
    def complete(argument:, ref: nil, **options)
      assert_capability(:completions, "completion/complete")
      params = { argument: argument }
      params[:ref] = ref if ref
      request({ method: "completion/complete", params: params }, options)
    end

    # Register client capabilities (must be called before connecting)
    def register_capabilities(new_capabilities)
      raise "Cannot register capabilities after connecting" if connected?

      @capabilities = merge_capabilities(@capabilities, new_capabilities)
    end

    # Get the current server capabilities
    def get_server_capabilities
      @server_capabilities
    end

    # Get server implementation info
    def get_server_info
      @server_info
    end

    # Get server instructions if provided
    def get_instructions
      @instructions
    end

    private

    def setup_transport_callbacks
      if @transport.respond_to?(:onmessage=)
        @transport.onmessage = method(:handle_message)
        @transport.onerror = method(:handle_error) if @transport.respond_to?(:onerror=)
        @transport.onclose = method(:handle_close) if @transport.respond_to?(:onclose=)
      else
        # Use the callback methods from Transport module
        @transport.on_message(&method(:handle_message))
        @transport.on_error(&method(:handle_error))
        @transport.on_disconnect(&method(:handle_close))
      end
    end

    def initialize_protocol(options = {})
      log_debug("Initializing MCP protocol...")

      params = {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: @capabilities,
        clientInfo: {
          name: "ActionMCP",
          version: ActionMCP.gem_version.to_s
        }
      }

      result = request({ method: "initialize", params: params }, options)

      if result.nil?
        raise "Server sent invalid initialize result"
      end

      unless SUPPORTED_PROTOCOL_VERSIONS.include?(result["protocolVersion"])
        raise "Server's protocol version is not supported: #{result["protocolVersion"]}"
      end

      @server_capabilities = result["capabilities"] || {}
      @server_info = result["serverInfo"] || {}
      @instructions = result["instructions"]

      # Send initialized notification
      notification({ method: "notifications/initialized" })

      @initialized = true
      log_debug("MCP protocol initialized successfully")
    end

    def request(message, options = {})
      # Don't assert initialized for the initialize request itself
      assert_initialized unless message[:method] == "initialize"

      message[:id] ||= SecureRandom.uuid

      log_debug("Sending request: #{message[:method]}")

      response = send_and_wait(message, options)

      if response["error"]
        raise "MCP Error: #{response["error"]["message"]}"
      end

      response["result"]
    end

    def notification(message)
      assert_initialized unless message[:method] == "notifications/initialized"

      log_debug("Sending notification: #{message[:method]}")
      send_message(message)
    end

    def send_and_wait(message, options = {})
      timeout = options[:timeout] || 30
      request_id = message[:id]

      # Simple synchronous implementation for now
      # In a real implementation, you'd want proper async handling
      send_message(message)

      # For simplicity, return a mock response
      # This would need to be properly implemented with actual transport layer
      { "result" => nil }
    end

    def send_message(message)
      json_message = message.is_a?(String) ? message : JSON.generate(message)
      @transport.send_message(json_message)
    end

    def handle_message(message)
      log_debug("Received message: #{message["method"] || "response"}")

      # Handle notifications
      if message["method"] && !message["id"]
        handle_notification(message)
      end

      # Responses are handled by send_and_wait
    end

    def handle_notification(message)
      case message["method"]
      when "notifications/resources/updated"
        log_debug("Resource update notification received")
      when "notifications/resources/list_changed"
        log_debug("Resource list changed notification received")
      when "notifications/tools/list_changed"
        log_debug("Tools list changed notification received")
      when "notifications/prompts/list_changed"
        log_debug("Prompts list changed notification received")
      else
        log_debug("Unknown notification: #{message["method"]}")
      end
    end

    def handle_error(error)
      log_error("Transport error: #{error.message}")
    end

    def handle_close
      log_debug("Transport closed")
      @connected = false
      @initialized = false
    end

    def assert_initialized
      raise "Client not initialized. Call connect() first." unless initialized?
    end

    def assert_capability(capability, method)
      unless @server_capabilities&.dig(capability.to_s)
        raise "Server does not support #{capability} (required for #{method})"
      end
    end

    def assert_resource_capability(sub_capability, method)
      unless @server_capabilities&.dig("resources", sub_capability.to_s)
        raise "Server does not support resource #{sub_capability} (required for #{method})"
      end
    end

    def merge_capabilities(existing, new_caps)
      # Simple merge - in a real implementation you might want more sophisticated merging
      existing.merge(new_caps)
    end

    def log_debug(message)
      @logger.debug("[ActionMCP::MCPClient] #{message}")
    end

    def log_info(message)
      @logger.info("[ActionMCP::MCPClient] #{message}")
    end

    def log_error(message)
      @logger.error("[ActionMCP::MCPClient] #{message}")
    end
  end

  # Factory method to create an appropriate client for the given endpoint
  #
  # @param endpoint [String] The endpoint to connect to (URL).
  # @param transport [Symbol] The transport type to use (:streamable_http, :sse for legacy)
  # @param session_store [Symbol] The session store type (:memory, :active_record)
  # @param session_id [String] Optional session ID for resuming connections
  # @param oauth_provider [ActionMCP::Client::OauthClientProvider] Optional OAuth provider for authentication
  # @param logger [Logger] The logger to use. Default is Logger.new($stdout).
  # @param options [Hash] Additional options to pass to the client constructor.
  #
  # @return [ActionMCP::MCPClient] An instance of the ActionMCP::MCPClient.
  def self.create_client(endpoint, transport: :streamable_http, session_store: nil, session_id: nil, oauth_provider: nil, logger: Logger.new($stdout), **options)
    unless endpoint =~ %r{\Ahttps?://}
      raise ArgumentError, "Only HTTP(S) endpoints are supported. STDIO and other transports are not supported."
    end

    # Create session store
    store = Client::SessionStoreFactory.create(session_store, **options) if session_store

    # Create transport
    transport_instance = create_transport(transport, endpoint, session_store: store, session_id: session_id, oauth_provider: oauth_provider, logger: logger, **options)

    logger.info("Creating ActionMCP::MCPClient for endpoint: #{endpoint}")
    MCPClient.new(transport: transport_instance, logger: logger, session_id: session_id, **options)
  end

  private_class_method def self.create_transport(type, endpoint, **options)
    case type.to_sym
    when :streamable_http
      Client::StreamableHttpTransport.new(endpoint, **options)
    when :sse
      # Legacy SSE transport (wrapped for compatibility)
      Client::StreamableClient.new(endpoint, **options)
    else
      raise ArgumentError, "Unknown transport type: #{type}"
    end
  end
end
