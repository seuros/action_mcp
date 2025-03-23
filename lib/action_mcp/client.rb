# frozen_string_literal: true

module ActionMCP
  # Creates a client appropriate for the given endpoint.
  #
  # @param endpoint [String] The endpoint to connect to (URL or command).
  # @param logger [Logger] The logger to use. Default is Logger.new($stdout).
  # @param options [Hash] Additional options to pass to the client constructor.
  #
  # @return [Client::SSEClient, Client::StdioClient] An instance of either SSEClient or StdioClient
  #   depending on the format of the endpoint.
  #
  # @example
  #   client = ActionMCP.create_client("http://127.0.0.1:3001/action_mcp")
  #   client.connect
  #
  # @example
  #   client = ActionMCP.create_client("some_command")
  #   client.execute
  def self.create_client(endpoint, logger: Logger.new($stdout), **options)
    if endpoint =~ %r{\Ahttps?://}
      logger.info("Creating SSE client for endpoint: #{endpoint}")
      Client::SSEClient.new(endpoint, logger: logger, **options)
    else
      logger.info("Creating STDIO client for command: #{endpoint}")
      Client::StdioClient.new(endpoint, logger: logger, **options)
    end
  end

  module Client
  end
end
