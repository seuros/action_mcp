# frozen_string_literal: true

module ActionMCP
  module Server
    # Correlates client notifications with server session state. Applications
    # can consume the resulting Rails notifications without ActionMCP keeping
    # callback objects in a persistent session.
    module ClientNotifications
      def receive_cancelled_notification(params)
        params = normalize_client_notification_params(params)
        request = if session.respond_to?(:cancel_in_flight_request)
                    session.cancel_in_flight_request(params[:requestId])
        end
        return log_unmatched_client_notification("cancellation", params[:requestId]) unless request

        instrument_client_notification("request_cancelled", request, params)
        request
      end

      def receive_progress_notification(params)
        params = normalize_client_notification_params(params)
        request = if session.respond_to?(:client_request_for_progress)
                    session.client_request_for_progress(params[:progressToken])
        end
        return log_unmatched_client_notification("progress token", params[:progressToken]) unless request

        instrument_client_notification("request_progress", request, params)
        request
      end

      def receive_task_status_notification(params)
        params = normalize_client_notification_params(params)
        request = if session.respond_to?(:client_request_for_task)
                    session.client_request_for_task(params[:taskId])
        end
        return log_unmatched_client_notification("task", params[:taskId]) unless request

        instrument_client_notification("task_status", request, params)
        request
      end

      private

      def normalize_client_notification_params(params)
        params.respond_to?(:to_h) ? params.to_h.with_indifferent_access : {}.with_indifferent_access
      end

      def instrument_client_notification(event, request, params)
        ActiveSupport::Notifications.instrument(
          "#{event}.action_mcp",
          session: session,
          request: request,
          params: params
        )
      end

      def log_unmatched_client_notification(kind, identifier)
        Rails.logger.debug("Ignoring MCP notification for unknown #{kind}: #{identifier.inspect}")
        nil
      end
    end
  end
end
