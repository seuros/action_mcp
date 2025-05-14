# frozen_string_literal: true

module ActionMCP
  module Client
    module Prompts
      # List all available prompts from the server
      # @param params [Hash] Optional parameters for pagination
      # @option params [String] :cursor Pagination cursor for fetching next page
      # @option params [Integer] :limit Maximum number of items to return
      # @return [String] Request ID for tracking the request
      def list_prompts(params = {})
        request_id = SecureRandom.uuid_v7

        # Send request with pagination parameters if provided
        request_params = {}
        request_params[:cursor] = params[:cursor] if params[:cursor]
        request_params[:limit] = params[:limit] if params[:limit]

        send_jsonrpc_request("prompts/list",
                             params: request_params.empty? ? nil : request_params,
                             id: request_id)

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
                             id: request_id)

        # Return request ID for tracking the request
        request_id
      end
    end
  end
end
