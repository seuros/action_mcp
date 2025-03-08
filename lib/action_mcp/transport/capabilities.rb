module ActionMCP
  module Transport
    module Capabilities
      def send_capabilities(request_id, params = {})
        @protocol_version = params["protocolVersion"]
        @client_info = params["clientInfo"]
        @client_capabilities = params["capabilities"]
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
    end
  end
end
