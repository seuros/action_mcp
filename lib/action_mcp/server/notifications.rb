# frozen_string_literal: true

module ActionMCP
  module Server
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

      # Updated to match MCP 2025-03-26 specification
      def send_progress_notification(progressToken:, progress:, total: nil, message: nil, **options)
        params = {
          progressToken: progressToken,
          progress: progress,
          total: total
        }
        params[:message] = message if message.present?
        params.merge!(options) if options.any?

        send_jsonrpc_notification("notifications/progress", params)
      end

      # Backward compatibility method for old API
      def send_progress_notification_legacy(token:, value:, message: nil)
        Rails.logger.warn("DEPRECATION: send_progress_notification with token/value is deprecated. Use progressToken/progress instead.")
        send_progress_notification(progressToken: token, progress: value, message: message, total: 0)
      end
    end
  end
end
