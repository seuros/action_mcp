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

        unless client_protocol_version.is_a?(String) && client_protocol_version.present?
          send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'protocolVersion'")
          return { type: :error, id: request_id, payload: { jsonrpc: "2.0", id: request_id, error: { code: -32602, message: "Missing or invalid 'protocolVersion'" } } }
        end
        # Check if the protocol version is supported
        unless ActionMCP::SUPPORTED_VERSIONS.include?(client_protocol_version)
          error_data = {
            supported: ActionMCP::SUPPORTED_VERSIONS,
            requested: client_protocol_version
          }
          send_jsonrpc_error(request_id, :invalid_params, "Unsupported protocol version", error_data)
          return { type: :error, id: request_id, payload: { jsonrpc: "2.0", id: request_id, error: { code: -32602, message: "Unsupported protocol version", data: error_data } } }
        end

        unless client_info.is_a?(Hash)
          send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'clientInfo'")
          return { type: :error, id: request_id, payload: { jsonrpc: "2.0", id: request_id, error: { code: -32602, message: "Missing or invalid 'clientInfo'" } } }
        end
        unless client_capabilities.is_a?(Hash)
          send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'capabilities'")
          return { type: :error, id: request_id, payload: { jsonrpc: "2.0", id: request_id, error: { code: -32602, message: "Missing or invalid 'capabilities'" } } }
        end



        # Store client information
        session.store_client_info(client_info)
        session.store_client_capabilities(client_capabilities)
        session.set_protocol_version(client_protocol_version)

        # Initialize the session
        unless session.initialize!
          send_jsonrpc_error(request_id, :internal_error, "Failed to initialize session")
          return { type: :error, id: request_id, payload: { jsonrpc: "2.0", id: request_id, error: { code: -32603, message: "Failed to initialize session" } } }
        end

        # Send the successful response with the protocol version the client requested
        capabilities_payload = session.server_capabilities_payload
        capabilities_payload[:protocolVersion] = client_protocol_version  # Use the client's requested version

        send_jsonrpc_response(request_id, result: capabilities_payload)
        { type: :responses, id: request_id, payload: { jsonrpc: "2.0", id: request_id, result: capabilities_payload } }
      end
    end
  end
end
