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
        unless ActionMCP.configuration.vibed_ignore_version || ActionMCP::SUPPORTED_VERSIONS.include?(client_protocol_version)
          error_data = {
            supported: ActionMCP::SUPPORTED_VERSIONS,
            requested: client_protocol_version
          }
          return send_jsonrpc_error(request_id, :invalid_params, "Unsupported protocol version", error_data)
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
          if existing_session && existing_session.initialized?
            # Resume existing session - update transport reference
            transport.instance_variable_set(:@session, existing_session)
            Rails.logger.info("Resuming existing session: #{session_id}")

            # Return existing session info
            capabilities_payload = existing_session.server_capabilities_payload
            capabilities_payload[:protocolVersion] = if ActionMCP.configuration.vibed_ignore_version
                                                       PROTOCOL_VERSION
            else
                                                       client_protocol_version
            end
            return send_jsonrpc_response(request_id, result: capabilities_payload)
          else
            Rails.logger.warn("Session #{session_id} not found or not initialized, creating new session")
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
        capabilities_payload[:protocolVersion] = if ActionMCP.configuration.vibed_ignore_version
                                                   PROTOCOL_VERSION
        else
                                                   client_protocol_version
        end

        send_jsonrpc_response(request_id, result: capabilities_payload)
      end
    end
  end
end
