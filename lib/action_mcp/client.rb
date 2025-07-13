# frozen_string_literal: true

require_relative "client/transport"
require_relative "client/session_store"
require_relative "client/streamable_http_transport"
require_relative "client/oauth_client_provider"
require_relative "client/jwt_client_provider"

module ActionMCP
  # Creates a client appropriate for the given endpoint.
  #
  # @param endpoint [String] The endpoint to connect to (URL).
  # @param transport [Symbol] The transport type to use (:streamable_http, :sse for legacy)
  # @param session_store [Symbol] The session store type (:memory, :active_record)
  # @param session_id [String] Optional session ID for resuming connections
  # @param oauth_provider [ActionMCP::Client::OauthClientProvider] Optional OAuth provider for authentication
  # @param jwt_provider [ActionMCP::Client::JwtClientProvider] Optional JWT provider for authentication
  # @param protocol_version [String] The MCP protocol version to use (defaults to ActionMCP::DEFAULT_PROTOCOL_VERSION)
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
  #
  # @example With OAuth authentication
  #   oauth_provider = ActionMCP::Client::OauthClientProvider.new(
  #     authorization_server_url: "https://oauth.example.com",
  #     redirect_url: "http://localhost:3000/callback",
  #     client_metadata: { client_name: "My App" }
  #   )
  #   client = ActionMCP.create_client(
  #     "http://127.0.0.1:3001/action_mcp",
  #     oauth_provider: oauth_provider
  #   )
  #
  # @example With JWT authentication
  #   jwt_provider = ActionMCP::Client::JwtClientProvider.new(
  #     token: "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
  #   )
  #   client = ActionMCP.create_client(
  #     "http://127.0.0.1:3001/action_mcp",
  #     jwt_provider: jwt_provider
  #   )
  def self.create_client(endpoint, transport: :streamable_http, session_store: nil, session_id: nil, oauth_provider: nil, jwt_provider: nil, protocol_version: nil, logger: Logger.new($stdout), **options)
    unless endpoint =~ %r{\Ahttps?://}
      raise ArgumentError, "Only HTTP(S) endpoints are supported. STDIO and other transports are not supported."
    end

    # Create session store
    store = Client::SessionStoreFactory.create(session_store, **options)

    # Create transport
    transport_instance = create_transport(transport, endpoint, session_store: store, session_id: session_id, oauth_provider: oauth_provider, jwt_provider: jwt_provider, protocol_version: protocol_version, logger: logger, **options)

    logger.info("Creating #{transport} client for endpoint: #{endpoint}")
    # Pass session_id and protocol_version to the client
    Client::Base.new(transport: transport_instance, logger: logger, session_id: session_id, protocol_version: protocol_version, **options)
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

  module Client
  end
end
