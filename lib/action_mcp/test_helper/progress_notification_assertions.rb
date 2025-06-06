# frozen_string_literal: true

module ActionMCP
  module TestHelper
    module ProgressNotificationAssertions
      # Assert that at least one progress notification was sent with the given token
      def assert_progress_notification_sent(token, message = nil)
        notifications = get_progress_notifications(token)
        assert notifications.any?,
               message || "Expected at least one progress notification with token #{token}, but none were sent"
      end

      # Assert that no progress notifications were sent with the given token
      def assert_no_progress_notification_sent(token, message = nil)
        notifications = get_progress_notifications(token)
        assert notifications.empty?,
               message || "Expected no progress notifications with token #{token}, but #{notifications.size} were sent"
      end

      # Assert that progress values increase monotonically
      def assert_progress_sequence_valid(token, message = nil)
        notifications = get_progress_notifications(token)
        progress_values = notifications.map { |n| n.params[:progress] }

        assert progress_values.each_cons(2).all? { |a, b| b > a },
               message || "Progress values must increase monotonically, but got: #{progress_values.inspect}"
      end

      # Assert specific fields in the latest progress notification
      def assert_progress_notification_includes(token, expected, message = nil)
        notifications = get_progress_notifications(token)
        assert notifications.any?, "No progress notifications found for token #{token}"

        notification = notifications.last
        expected.each do |key, value|
          actual = notification.params[key]
          assert_equal value, actual,
                       message || "Expected notification to have #{key}: #{value.inspect}, but got: #{actual.inspect}"
        end
      end

      # Assert the total count of progress notifications for a token
      def assert_progress_notification_count(token, expected_count, message = nil)
        notifications = get_progress_notifications(token)
        actual_count = notifications.size

        assert_equal expected_count, actual_count,
                     message || "Expected #{expected_count} progress notifications for token #{token}, but got #{actual_count}"
      end

      # Assert notification follows MCP spec structure
      def assert_progress_notification_valid(notification, message = nil)
        # Convert to hash if it's a notification object
        data = notification.respond_to?(:to_h) ? notification.to_h : notification

        # Verify JSON-RPC structure
        assert_equal "2.0", data["jsonrpc"] || data[:jsonrpc],
                     message || "Notification must have jsonrpc: 2.0"
        assert_equal "notifications/progress", data[:method],
                     message || "Notification method must be notifications/progress"
        assert_nil data[:id],
                   message || "Notifications must not have an id field"

        # Verify params
        params = data[:params]
        assert params, "Notification must have params"
        assert params[:progressToken], "Notification must have progressToken"
        assert params[:progress], "Notification must have progress value"

        # Type checks
        assert [ String, Integer ].include?(params[:progressToken].class),
               "progressToken must be string or integer"
        assert params[:progress].is_a?(Numeric),
               "progress must be numeric"

        # Optional field type checks if present
        if params.key?(:total)
          assert params[:total].is_a?(Numeric),
                 "total must be numeric when present"
        end

        if params.key?(:message)
          assert params[:message].is_a?(String),
                 "message must be string when present"
        end
      end

      # Get the current session store (with helpful error if not using test store)
      def progress_session_store
        store = ActionMCP::Server.session_store
        unless store.respond_to?(:notifications_for_token)
          raise "Session store #{store.class} does not support notification tracking. " \
                "Use TestSessionStore for progress notification tests."
        end
        store
      end

      private

      def get_progress_notifications(token)
        progress_session_store.notifications_for_token(token)
      end
    end
  end
end
