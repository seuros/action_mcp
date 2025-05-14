# frozen_string_literal: true

module ActionMCP
  module Client
    module Resources
      # List all available resources from the server
      # @param params [Hash] Optional parameters for pagination
      # @option params [String] :cursor Pagination cursor for fetching next page
      # @option params [Integer] :limit Maximum number of items to return
      # @return [String] Request ID for tracking the request
      def list_resources(params = {})
        request_id = SecureRandom.uuid_v7

        # Send request with pagination parameters if provided
        request_params = {}
        request_params[:cursor] = params[:cursor] if params[:cursor]
        request_params[:limit] = params[:limit] if params[:limit]

        send_jsonrpc_request("resources/list",
                             params: request_params.empty? ? nil : request_params,
                             id: request_id)

        # Return request ID for tracking the request
        request_id
      end

      # List resource templates from the server
      # @param params [Hash] Optional parameters for pagination
      # @option params [String] :cursor Pagination cursor for fetching next page
      # @option params [Integer] :limit Maximum number of items to return
      # @return [String] Request ID for tracking the request
      def list_resource_templates(params = {})
        request_id = SecureRandom.uuid_v7

        # Send request with pagination parameters if provided
        request_params = {}
        request_params[:cursor] = params[:cursor] if params[:cursor]
        request_params[:limit] = params[:limit] if params[:limit]

        send_jsonrpc_request("resources/templates/list",
                             params: request_params.empty? ? nil : request_params,
                             id: request_id)

        # Return request ID for tracking the request
        request_id
      end

      # Read a specific resource
      # @param uri [String] URI of the resource to read
      # @return [String] Request ID for tracking the request
      def read_resource(uri)
        request_id = SecureRandom.uuid_v7

        # Send request
        send_jsonrpc_request("resources/read",
                             params: { uri: uri },
                             id: request_id)

        # Return request ID for tracking the request
        request_id
      end

      # Subscribe to updates for a specific resource
      # @param uri [String] URI of the resource to subscribe to
      # @param update_callback [Proc] Callback for resource updates
      # @return [String] Request ID for tracking the request
      def subscribe_resource(uri, update_callback)
        @resource_subscriptions ||= {}
        @resource_subscriptions[uri] = update_callback

        request_id = SecureRandom.uuid_v7

        # Send request
        send_jsonrpc_request("resources/subscribe",
                             params: { uri: uri },
                             id: request_id)

        # Return request ID for tracking the request
        request_id
      end

      # Unsubscribe from updates for a specific resource
      # @param uri [String] URI of the resource to unsubscribe from
      # @return [String] Request ID for tracking the request
      def unsubscribe_resource(uri)
        @resource_subscriptions&.delete(uri)

        request_id = SecureRandom.uuid_v7

        # Send request
        send_jsonrpc_request("resources/unsubscribe",
                             params: { uri: uri },
                             id: request_id)

        # Return request ID for tracking the request
        request_id
      end
    end
  end
end
