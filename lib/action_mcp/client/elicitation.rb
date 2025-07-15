# frozen_string_literal: true

module ActionMCP
  module Client
    # Handles elicitation requests from servers
    module Elicitation
      # Process elicitation request from server
      # @param id [String, Integer] The request ID
      # @param params [Hash] The elicitation parameters
      def process_elicitation_request(id, params)
        params["message"]
        params["requestedSchema"]

        # In a real implementation, this would prompt the user
        # For now, we'll just return a decline response
        # Actual implementations should override this method
        send_jsonrpc_response(id, result: {
                                action: "decline"
                              })
      end

      # Send elicitation response
      # @param id [String, Integer] The request ID
      # @param action [String] The action taken ("accept", "decline", "cancel")
      # @param content [Hash, nil] The form data if action is "accept"
      def send_elicitation_response(id, action:, content: nil)
        result = { action: action }
        result[:content] = content if action == "accept" && content

        send_jsonrpc_response(id, result: result)
      end
    end
  end
end
