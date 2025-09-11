# frozen_string_literal: true

module ActionMCP
  module Server
    module Handlers
      # Handler for MCP logging/setLevel requests
      module LoggingHandler
        # Handle logging/setLevel request
        # @param id [String] The request ID
        # @param params [Hash] Request parameters containing level
        # @return [Hash] Empty hash on success
        def handle_logging_set_level(id, params)
          # Check if logging is enabled
          unless ActionMCP.configuration.logging_enabled
            send_jsonrpc_error(id, -32601, "Logging not enabled")
            return
          end

          # Extract and validate level parameter
          level = params[:level] || params["level"]
          unless level
            send_jsonrpc_error(id, -32602, "Missing required parameter: level")
            return
          end

          begin
            # Validate and set the new level
            ActionMCP::Logging.set_level(level)

            # Send successful response (empty object per MCP spec)
            send_jsonrpc_response(id, result: {})
          rescue ArgumentError => e
            # Invalid level
            send_jsonrpc_error(id, -32602, "Invalid log level: #{e.message}")
          rescue StandardError => e
            # Internal error
            send_jsonrpc_error(id, -32603, "Internal error: #{e.message}")
          end
        end
      end
    end
  end
end
