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
        session_id = params["sessionId"]

        unless client_protocol_version.is_a?(String) && client_protocol_version.present?
          return send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'protocolVersion'")
        end

        unless ActionMCP::SUPPORTED_VERSIONS.include?(client_protocol_version)
          error_message = "Unsupported protocol version. Client requested '#{client_protocol_version}' but server supports #{ActionMCP::SUPPORTED_VERSIONS.join(', ')}"
          error_data = {
            supported: ActionMCP::SUPPORTED_VERSIONS,
            requested: client_protocol_version
          }
          return send_jsonrpc_error(request_id, :invalid_params, error_message, error_data)
        end

        unless client_info.is_a?(Hash)
          return send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'clientInfo'")
        end
        unless client_capabilities.is_a?(Hash)
          return send_jsonrpc_error(request_id, :invalid_params, "Missing or invalid 'capabilities'")
        end

        # Handle session resumption if sessionId provided
        if session_id
          existing_session = ActionMCP::Session.find_by(id: session_id)
          if existing_session&.initialized?
            # Resume existing session - update transport reference
            transport.instance_variable_set(:@session, existing_session)

            # Return existing session info
            capabilities_payload = existing_session.server_capabilities_payload
            capabilities_payload[:protocolVersion] = client_protocol_version
            return send_jsonrpc_response(request_id, result: capabilities_payload)
          end
        end

        # Create new session if not resuming
        session.store_client_info(client_info)
        session.store_client_capabilities(client_capabilities)
        session.set_protocol_version(client_protocol_version)

        unless session.initialize!
          return send_jsonrpc_error(request_id, :internal_error, "Failed to initialize session")
        end

        capabilities_payload = session.server_capabilities_payload
        capabilities_payload[:protocolVersion] = client_protocol_version

        send_jsonrpc_response(request_id, result: capabilities_payload)
      end
    end
  end
end
