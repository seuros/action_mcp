# frozen_string_literal: true

module ActionMCP
  module Server
    module MessagingService
      include BaseMessaging  # For write_message

      attr_accessor :messaging_mode

      def send_jsonrpc_request(method, params: nil, id: SecureRandom.uuid_v7)
        send_message(:request, method: method, params: params, id: id)
      end

      def send_jsonrpc_response(request_id, result: nil, error: nil)
        args = { id: request_id }
        args[:result] = result unless result.nil?
        args[:error] = error unless error.nil?
        send_message(:response, **args)
      end

      def send_jsonrpc_notification(method, params = nil)
        send_message(:notification, method: method, params: params)
      end

      def send_jsonrpc_error(request_id, symbol, message, data = nil)
        error = JSON_RPC::JsonRpcError.new(symbol, message: message, data: data)
        send_jsonrpc_response(request_id, error: error)
      end

      # Specific notifications
      def send_resources_list_changed_notification
        send_jsonrpc_notification("notifications/resources/list_changed")
      end

      def send_resource_updated_notification(uri)
        send_jsonrpc_notification("notifications/resources/updated", { uri: uri })
      end

      def send_tools_list_changed_notification
        send_jsonrpc_notification("notifications/tools/list_changed")
      end

      def send_prompts_list_changed_notification
        send_jsonrpc_notification("notifications/prompts/list_changed")
      end

      def send_logging_message_notification(level:, data:, logger: nil)
        params = { level: level, data: data }
        params[:logger] = logger if logger.present?
        send_jsonrpc_notification("notifications/logging/message", params)
      end

      def send_progress_notification(progressToken:, progress:, total: nil, message: nil, **options)
        params = { progressToken: progressToken, progress: progress }
        params[:total] = total unless total.nil?
        params[:message] = message if message.present?
        params.merge!(options) if options.any?
        send_jsonrpc_notification("notifications/progress", params)
      end

      private

      def send_message(type, **args)
        message = case type
        when :request
          JSON_RPC::Request.new(
            id: args[:id],
            method: args[:method],
            params: args[:params]
          )
        when :response
          response_args = { id: args[:id] }
          response_args[:result] = args[:result] if args.key?(:result)
          response_args[:error] = args[:error] if args.key?(:error)
          JSON_RPC::Response.new(**response_args)
        when :notification
          JSON_RPC::Notification.new(
            method: args[:method],
            params: args[:params]
          )
        end

        if messaging_mode == :return
          write_message(message)
          message
        else
          write_message(message)
          nil
        end
      end
    end
  end
end
