# frozen_string_literal: true

module ActionMCP
  module Client
    module RequestTimeouts
      # Default timeout in seconds
      DEFAULT_TIMEOUT = 1.0

      # Load resources with timeout support - blocking until response or timeout
      # @param method_name [Symbol] The method to call for loading (e.g., :list_resources)
      # @param force [Boolean] Whether to force reload even if already loaded
      # @param timeout [Float] Timeout in seconds
      # @return [Boolean] Success status
      def load_with_timeout(method_name, force: false, timeout: DEFAULT_TIMEOUT)
        return true if @loaded && !force

        # Make the request and store its ID
        request_id = client.send(method_name)

        start_time = Time.now

        # Wait until either:
        # 1. The collection is loaded (@loaded becomes true from JsonRpcHandler)
        # 2. The timeout is reached
        while !@loaded && (Time.now - start_time) < timeout
          sleep(0.1)
        end

        # If we timed out
        unless @loaded
          request = client.session.messages.requests.find_by(jsonrpc_id: request_id)

          if request && !request.request_acknowledged?
            # Send cancel notification
            client.send_jsonrpc_notification("notifications/cancelled", {
              requestId: request_id,
              reason: "Request timed out after #{timeout} seconds"
            })

            # Mark as cancelled in the database
            request.update(request_cancelled: true)

            log_error("Request #{method_name} timed out after #{timeout} seconds")
          end

          # Mark as loaded even though we timed out
          @loaded = true
          return false
        end

        # Collection was successfully loaded
        true
      end

      private

      def handle_timeout(request_id, method_name, timeout)
        # Find the request
        request = client.session.messages.requests.find_by(jsonrpc_id: request_id)

        if request && !request.request_acknowledged?
          # Send cancel notification
          client.send_jsonrpc_notification("notifications/cancelled", {
            requestId: request_id,
            reason: "Request timed out after #{timeout} seconds"
          })

          # Mark as cancelled in the database
          request.update(request_cancelled: true)

          log_error("Request #{method_name} timed out after #{timeout} seconds")
        end
      end
    end
  end
end
