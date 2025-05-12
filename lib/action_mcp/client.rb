# frozen_string_literal: true

module ActionMCP
  # Creates a client appropriate for the given endpoint.
  #
  # @param endpoint [String] The endpoint to connect to (URL).
  # @param logger [Logger] The logger to use. Default is Logger.new($stdout).
  # @param options [Hash] Additional options to pass to the client constructor.
  #
  # @return [Client::SSEClient] An instance of SSEClient for HTTP(S) endpoints.
  #
  # @example
  #   client = ActionMCP.create_client("http://127.0.0.1:3001/action_mcp")
  #   client.connect
  def self.create_client(endpoint, logger: Logger.new($stdout), **options)
    if endpoint =~ %r{\Ahttps?://}
      logger.info("Creating SSE client for endpoint: #{endpoint}")
      Client::SSEClient.new(endpoint, logger: logger, **options)
    else
      raise ArgumentError, "Only HTTP(S) endpoints are supported. STDIO and other transports are not supported."
    end
  end

  module Client
  end
end
