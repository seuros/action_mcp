# frozen_string_literal: true

module ActionMCP
  module Client
    module Prompts
      # List all available prompts from the server
      # @return [String] Request ID for tracking the request
      def list_prompts
        request_id = SecureRandom.uuid_v7

        # Send request
        send_jsonrpc_request("prompts/list", id: request_id)

        # Return request ID for tracking the request
        request_id
      end

      # Get a specific prompt with arguments
      # @param name [String] Name of the prompt to get
      # @param arguments [Hash] Arguments to pass to the prompt
      # @return [String] Request ID for tracking the request
      def get_prompt(name, arguments = {})
        request_id = SecureRandom.uuid_v7

        # Send request
        send_jsonrpc_request("prompts/get",
                             params: {
                               name: name,
                               arguments: arguments
                             },
                             id: request_id
        )

        # Return request ID for tracking the request
        request_id
      end
    end
  end
end
