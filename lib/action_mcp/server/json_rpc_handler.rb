# frozen_string_literal: true

module ActionMCP
  module Server
    class JsonRpcHandler < JsonRpcHandlerBase
      include Handlers::ResourceHandler
      include Handlers::ToolHandler
      include Handlers::PromptHandler
      include ErrorHandling
      include ErrorAware

      # Handle server-specific methods
      # @param request [JSON_RPC::Request, JSON_RPC::Notification, JSON_RPC::Response]
      def call(request)
        read(request.to_h)

        case request
        when JSON_RPC::Request
          handle_request(request)
        when JSON_RPC::Notification
          handle_notification(request)
        when JSON_RPC::Response
          handle_response(request)
        end
      end

      private

      def handle_request(request)
        id = request.id
        rpc_method = request.method
        params = request.params

        with_error_handling(id) do
          common_method = handle_common_methods(rpc_method, id, params)
          return common_method if common_method
          route_to_handler(rpc_method, id, params)
        end
      end

      def route_to_handler(rpc_method, id, params)
        case rpc_method
        when Methods::INITIALIZE
          handle_initialize(id, params)
        when %r{^prompts/}
          process_prompts(rpc_method, id, params)
        when %r{^resources/}
          process_resources(rpc_method, id, params)
        when %r{^tools/}
          process_tools(rpc_method, id, params)
        when Methods::COMPLETION_COMPLETE
          process_completion_complete(id, params)
        else
          raise JSON_RPC::JsonRpcError.new(:method_not_found, message: "Method not found: #{rpc_method}")
        end
      end

      def handle_initialize(id, params)
        transport.send_capabilities(id, params)
      end

      def handle_notification(notification)
        method_name = notification.method.to_s
        params = notification.params || {}

        process_notifications(method_name, params)
        nil
      end

      def handle_response(response)
        Rails.logger.debug("Received response: #{response.inspect}")
        response
      end


      def process_completion_complete(id, params)
        transport.send_jsonrpc_response(id, result: build_completion_result)
      end

      def process_notifications(rpc_method, params)
        case rpc_method
        when Methods::NOTIFICATIONS_INITIALIZED
          transport.initialize!
        else
          super
        end
      end

      def build_response_payload(response)
        {
          jsonrpc: "2.0",
          id: response.id,
          result: response.result
        }
      end

      def build_completion_result
        {
          completion: { values: [], total: 0, hasMore: false }
        }
      end
    end
  end
end
