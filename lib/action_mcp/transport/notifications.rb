# frozen_string_literal: true

module ActionMCP
  module Transport
    module Notifications
      # Notify client that the resources list has changed
      def send_resources_list_changed_notification
        send_jsonrpc_notification("notifications/resources/list_changed")
      end

      # Notify client that a specific resource has been updated
      def send_resource_updated_notification(uri)
        send_jsonrpc_notification("notifications/resources/updated", { uri: })
      end

      # Notify client that the tools list has changed
      def send_tools_list_changed_notification
        send_jsonrpc_notification("notifications/tools/list_changed")
      end

      # Notify client that the prompts list has changed
      def send_prompts_list_changed_notification
        send_jsonrpc_notification("notifications/prompts/list_changed")
      end

      # Send a logging message to the client
      def send_logging_message_notification(level:, data:, logger: nil)
        params = {
          level: level,
          data: data
        }
        params[:logger] = logger if logger.present?

        send_jsonrpc_notification("notifications/logging/message", params)
      end

      # Send progress notification for an asynchronous operation
      def send_progress_notification(token:, value:, message: nil)
        params = {
          token: token,
          value: value
        }
        params[:message] = message if message.present?

        send_jsonrpc_notification("$/progress", params)
      end
    end
  end
end
