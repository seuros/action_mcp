module ActionMCP
  module Transport
    module Capabilities
      def send_capabilities(request_id, params = {})
        @protocol_version = params["protocolVersion"]
        @client_info = params["clientInfo"]
        @client_capabilities = params["capabilities"]
        session.store_client_info(@client_info)
        session.store_client_capabilities(@client_capabilities)
        session.set_protocol_version(@protocol_version)
        session.save
        # TODO , if the server don't support the protocol version, send a response with error
        send_jsonrpc_response(request_id, result: session.server_capabilities_payload)
      end
    end
  end
end
