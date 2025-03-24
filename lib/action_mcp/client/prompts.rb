# frozen_string_literal: true

module ActionMCP
  module Client
    module Prompts
      # List all available prompts from the server
      # @return [Array<Hash>] List of available prompts with their metadata
      def list_prompts
        request_id = SecureRandom.uuid_v7

        # Send request
        send_jsonrpc_request("prompts/list", id: request_id)
      end

      # Get a specific prompt with arguments
      # @param name [String] Name of the prompt to get
      # @param arguments [Hash] Arguments to pass to the prompt
      # @return [Hash] Prompt content with messages
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
      end
    end
  end
end
