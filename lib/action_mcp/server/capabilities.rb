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
        # 1. Validate Parameters
        client_protocol_version = params["protocolVersion"]
        client_info = params["clientInfo"]
        client_capabilities = params["capabilities"]

        unless client_protocol_version.is_a?(String) && client_protocol_version.present?
          return send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'protocolVersion'")
        end
        # Basic check, could be more specific based on spec requirements
        unless client_info.is_a?(Hash)
          return send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'clientInfo'")
        end
        unless client_capabilities.is_a?(Hash)
          return send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'capabilities'")
        end

        # 2. Check Protocol Version
        server_protocol_version = ActionMCP::PROTOCOL_VERSION
        unless client_protocol_version == server_protocol_version
          error_data = {
            supported: [ server_protocol_version ],
            requested: client_protocol_version
          }
          # Using -32602 Invalid Params code as per spec example for version mismatch
          return send_jsonrpc_error(request_id, :invalid_params, "Unsupported protocol version", error_data)
        end

        # 3. Store Info and Initialize Session
        session.store_client_info(client_info)
        session.store_client_capabilities(client_capabilities)
        session.set_protocol_version(client_protocol_version) # Store the agreed-upon version

        # Attempt to initialize (this saves the session if new)
        unless session.initialize!
          # Handle potential initialization failure (e.g., validation error on save)
          return send_jsonrpc_error(request_id, :internal_error, "Failed to initialize session")
        end

        # 4. Return Success Response Payload
        send_jsonrpc_response(request_id, result: session.server_capabilities_payload)
      end
    end
  end
end
