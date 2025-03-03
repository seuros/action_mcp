module ActionMCP
  module Transport
    module Capabilities
      def send_capabilities(request_id, params = {})
        @protocol_version = params["protocolVersion"]
        @client_info = params["clientInfo"]
        @client_capabilities = params["capabilities"]
        TransportHandler.logger.debug("Client capabilities stored: #{@client_capabilities}")
        capabilities = ActionMCP.configuration.capabilities

        payload = {
          protocolVersion: PROTOCOL_VERSION,
          serverInfo: {
            name: ActionMCP.configuration.name,
            version: ActionMCP.configuration.version
          }
        }.merge(capabilities)
        send_jsonrpc_response(request_id, result: payload)
      end

      def initialized!
        @initialized = true
        TransportHandler.logger.debug("Transport initialized.")
      end
    end
  end
end
