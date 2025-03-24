# frozen_string_literal: true

module ActionMCP
  module Client
    module Tools
      # List all available tools from the server
      # @return [Array<Hash>] List of available tools with their metadata
      def list_tools
        request_id = SecureRandom.uuid_v7

        # Send request
        send_jsonrpc_request("tools/list", id: request_id)
      end

      # Call a specific tool on the server
      # @param name [String] Name of the tool to call
      # @param arguments [Hash] Arguments to pass to the tool
      # @return [Hash] The result of the tool execution
      def call_tool(name, arguments)
        request_id = SecureRandom.uuid_v7

        # Send request
        send_jsonrpc_request("tools/call",
                             params: {
                               name: name,
                               arguments: arguments
                             },
                             id: request_id
        )
      end
    end
  end
end
