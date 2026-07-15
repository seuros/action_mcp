# frozen_string_literal: true

module ActionMCP
  module Server
    module Capabilities
      # Handles the 'initialize' request. Validates parameters, checks protocol version,
      # stores client info, initializes the session, and returns the server capabilities payload
      # or an error payload.
      # @param request_id [String, Integer] The JSON-RPC request ID.
      # @param params [Hash] The JSON-RPC parameters.
      # @return [Hash] A hash representing the JSON-RPC response (success or error).
      def send_capabilities(request_id, params = {})
        client_protocol_version = params["protocolVersion"]
        client_info = params["clientInfo"]
        client_capabilities = params["capabilities"]
        unless client_protocol_version.is_a?(String)
          return send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'protocolVersion'")
        end

        unless client_info.is_a?(Hash) && client_info["name"].is_a?(String) && client_info["version"].is_a?(String)
          return send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'clientInfo'")
        end
        unless client_capabilities.is_a?(Hash)
          return send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'capabilities'")
        end

        negotiated_version = if ActionMCP::SUPPORTED_VERSIONS.include?(client_protocol_version)
                               client_protocol_version
        else
                               ActionMCP::LATEST_VERSION
        end

        session.store_client_info(client_info)
        session.store_client_capabilities(client_capabilities)
        session.set_protocol_version(negotiated_version)

        unless session.begin_initialization!
          return send_jsonrpc_error(request_id, :invalid_request, "Session has already started initialization")
        end

        capabilities_payload = session.server_capabilities_payload
        capabilities_payload[:protocolVersion] = negotiated_version

        send_jsonrpc_response(request_id, result: capabilities_payload)
      end
    end
  end
end
