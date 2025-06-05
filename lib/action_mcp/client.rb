# frozen_string_literal: true

require_relative "client/transport"
require_relative "client/session_store"
require_relative "client/streamable_http_transport"

module ActionMCP
  # Creates a client appropriate for the given endpoint.
  #
  # @param endpoint [String] The endpoint to connect to (URL).
  # @param transport [Symbol] The transport type to use (:streamable_http, :sse for legacy)
  # @param session_store [Symbol] The session store type (:memory, :active_record)
  # @param session_id [String] Optional session ID for resuming connections
  # @param logger [Logger] The logger to use. Default is Logger.new($stdout).
  # @param options [Hash] Additional options to pass to the client constructor.
  #
  # @return [Client::Base] An instance of the appropriate client.
  #
  # @example Basic usage
  #   client = ActionMCP.create_client("http://127.0.0.1:3001/action_mcp")
  #   client.connect
  #
  # @example With specific transport and session store
  #   client = ActionMCP.create_client(
  #     "http://127.0.0.1:3001/action_mcp",
  #     transport: :streamable_http,
  #     session_store: :active_record,
  #     session_id: "existing-session-123"
  #   )
  #
  # @example Memory-based for development
  #   client = ActionMCP.create_client(
  #     "http://127.0.0.1:3001/action_mcp",
  #     session_store: :memory
  #   )
  def self.create_client(endpoint, transport: :streamable_http, session_store: nil, session_id: nil, logger: Logger.new($stdout), **options)
    unless endpoint =~ %r{\Ahttps?://}
      raise ArgumentError, "Only HTTP(S) endpoints are supported. STDIO and other transports are not supported."
    end

    # Create session store
    store = Client::SessionStoreFactory.create(session_store, **options)

    # Create transport
    transport_instance = create_transport(transport, endpoint, session_store: store, session_id: session_id, logger: logger, **options)

    logger.info("Creating #{transport} client for endpoint: #{endpoint}")
    # Pass session_id to the client
    Client::Base.new(transport: transport_instance, logger: logger, session_id: session_id, **options)
  end

  private_class_method def self.create_transport(type, endpoint, **options)
    case type.to_sym
    when :streamable_http
      Client::StreamableHttpTransport.new(endpoint, **options)
    when :sse
      # Legacy SSE transport (wrapped for compatibility)
      Client::LegacySSETransport.new(endpoint, **options)
    else
      raise ArgumentError, "Unknown transport type: #{type}"
    end
  end

  module Client
  end
end
