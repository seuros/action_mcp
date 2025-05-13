# frozen_string_literal: true

module ActionMCP
  module Server
    class JsonRpcHandler < JsonRpcHandlerBase
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
        @current_request_id = id = request.id
        rpc_method = request.method
        params = request.params

        case rpc_method
        when "initialize"
          message = transport.send_capabilities(id, params)
          extract_message_payload(message, id)
        when %r{^prompts/}
          process_prompts(rpc_method, id, params)
        when %r{^resources/}
          process_resources(rpc_method, id, params)
        when %r{^tools/}
          process_tools(rpc_method, id, params)
        when "completion/complete"
          process_completion_complete(id, params)
        else
          error_response(id, :method_not_found, "Method not found: #{rpc_method}")
        end
      end

      def handle_notification(notification)
        @current_request_id = nil

        begin
          method_name = notification.method.to_s
          params = notification.params || {}

          process_notifications(method_name, params)
          { type: :notifications_only }
        rescue StandardError => e
          Rails.logger.error("Error handling notification #{notification.method}: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          { type: :notifications_only }
        end
      end

      def handle_response(response)
        Rails.logger.debug("Received response: #{response.inspect}")
        {
          type: :responses,
          request_id: response.id,
          payload: {
            jsonrpc: "2.0",
            id: response.id,
            result: response.result
          }
        }
      end

      def process_prompts(rpc_method, id, params)
        params ||= {}

        case rpc_method
        when "prompts/get"
          name = params["name"] || params[:name]
          arguments = params["arguments"] || params[:arguments] || {}
          message = transport.send_prompts_get(id, name, arguments)
          extract_message_payload(message, id)
        when "prompts/list"
          message = transport.send_prompts_list(id)
          extract_message_payload(message, id)
        else
          Rails.logger.warn("Unknown prompts method: #{rpc_method}")
          error_response(id, :method_not_found, "Unknown prompts method: #{rpc_method}")
        end
      end

      def process_tools(rpc_method, id, params)
        params ||= {}

        case rpc_method
        when "tools/list"
          message = transport.send_tools_list(id, params)
          extract_message_payload(message, id)
        when "tools/call"
          name = params["name"] || params[:name]
          arguments = params["arguments"] || params[:arguments] || {}

          return error_response(id, :invalid_params, "Tool name is required") if name.nil?

          message = transport.send_tools_call(id, name, arguments)
          extract_message_payload(message, id)
        else
          Rails.logger.warn("Unknown tools method: #{rpc_method}")
          error_response(id, :method_not_found, "Unknown tools method: #{rpc_method}")
        end
      end

      def process_resources(rpc_method, id, params)
        params ||= {}

        case rpc_method
        when "resources/list"
          message = transport.send_resources_list(id)
          extract_message_payload(message, id)
        when "resources/templates/list"
          message = transport.send_resource_templates_list(id)
          extract_message_payload(message, id)
        when "resources/read"
          return error_response(id, :invalid_params, "Resource URI is required") if params.nil? || params.empty?

          message = transport.send_resource_read(id, params)
          extract_message_payload(message, id)
        when "resources/subscribe"
          uri = params["uri"] || params[:uri]
          return error_response(id, :invalid_params, "Resource URI is required") if uri.nil?

          message = transport.send_resource_subscribe(id, uri)
          extract_message_payload(message, id)
        when "resources/unsubscribe"
          uri = params["uri"] || params[:uri]
          return error_response(id, :invalid_params, "Resource URI is required") if uri.nil?

          message = transport.send_resource_unsubscribe(id, uri)
          extract_message_payload(message, id)
        else
          Rails.logger.warn("Unknown resources method: #{rpc_method}")
          error_response(id, :method_not_found, "Unknown resources method: #{rpc_method}")
        end
      end

      def process_completion_complete(id, params)
        params ||= {}

        result = transport.send_jsonrpc_response(id, result: {
          completion: { values: [], total: 0, hasMore: false }
        })

        if result.is_a?(ActionMCP::Session::Message)
          extract_message_payload(result, id)
        else
          wrap_transport_result(result, id)
        end
      end

      def process_notifications(rpc_method, params)
        case rpc_method
        when "notifications/initialized"
          Rails.logger.info "Client notified initialization complete"
          transport.initialize!
        else
          super
        end
      end

      def extract_message_payload(message, id)
        if message.is_a?(ActionMCP::Session::Message)
          {
            type: :responses,
            request_id: id,
            payload: message.message_json
          }
        else
        message
        end
      end

      def wrap_transport_result(transport_result, id)
        if transport_result.is_a?(Hash) && transport_result[:type]
          transport_result
        else
          {
            type: :responses,
            request_id: id,
            payload: transport_result
          }
        end
      end

      def error_response(id, code, message)
        error_code = case code
        when :method_not_found then -32_601
        when :invalid_params then -32_602
        when :internal_error then -32_603
        else -32_000
        end

        {
          type: :error,
          request_id: id,
          payload: {
            jsonrpc: "2.0",
            id: id,
            error: { code: error_code, message: message }
          },
          status: :bad_request
        }
      end
    end
  end
end
