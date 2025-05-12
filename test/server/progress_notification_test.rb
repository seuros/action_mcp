require "test_helper"

module ActionMCP
  module Server
    class ProgressNotificationTest < ActiveSupport::TestCase
      include TransportMocks

      setup do
        @session = DummySession.new
        @handler = TransportHandler.new(@session)
      end

      test "sends progress notification with required fields (2025-03-26 spec)" do
        @handler.send_progress_notification(progressToken: "task_123", progress: 0.5)

        notification = @session.written
        assert_instance_of JSON_RPC::Notification, notification
        assert_equal "notifications/progress", notification.method

        params = notification.params
        assert_equal "task_123", params[:progressToken]
        assert_equal 0.5, params[:progress]
        refute params.key?(:total), "Total should not be present when not provided"
        refute params.key?(:message), "Message should not be present when not provided"
      end

      test "sends progress notification with all fields (2025-03-26 spec)" do
        @handler.send_progress_notification(
          progressToken: "task_456",
          progress: 50,
          total: 100,
          message: "Downloading file 3 of 4"
        )

        notification = @session.written
        assert_instance_of JSON_RPC::Notification, notification
        assert_equal "notifications/progress", notification.method

        params = notification.params
        assert_equal "task_456", params[:progressToken]
        assert_equal 50, params[:progress]
        assert_equal 100, params[:total]
        assert_equal "Downloading file 3 of 4", params[:message]
      end

      test "progress notification with only progressToken and progress" do
        @handler.send_progress_notification(
          progressToken: "task_789",
          progress: 100
        )

        notification = @session.written
        params = notification.params
        assert_equal "task_789", params[:progressToken]
        assert_equal 100, params[:progress]
        refute params.key?(:total)
        refute params.key?(:message)
      end

      test "progress notification with total but no message" do
        @handler.send_progress_notification(
          progressToken: "task_101",
          progress: 25,
          total: 200
        )

        notification = @session.written
        params = notification.params
        assert_equal "task_101", params[:progressToken]
        assert_equal 25, params[:progress]
        assert_equal 200, params[:total]
        refute params.key?(:message)
      end

      test "progress notification conforms to MCP 2025-03-26 JSON-RPC structure" do
        @handler.send_progress_notification(
          progressToken: "spec_test",
          progress: 75,
          total: 150,
          message: "Testing MCP 2025 compliance"
        )

        notification = @session.written
        # Access jsonrpc through the to_h method
        json_representation = notification.to_h
        assert_equal "2.0", json_representation["jsonrpc"]
        assert_equal "notifications/progress", notification.method

        params = notification.params
        assert_instance_of Hash, params
        assert_equal "spec_test", params[:progressToken]
        assert_equal 75, params[:progress]
        assert_equal 150, params[:total]
        assert_equal "Testing MCP 2025 compliance", params[:message]
      end

      test "progress notification supports string and integer progressTokens" do
        # String token
        @handler.send_progress_notification(progressToken: "string_token", progress: 0.5)
        notification = @session.written
        assert_equal "string_token", notification.params[:progressToken]

        # Integer token
        @handler.send_progress_notification(progressToken: 12345, progress: 0.75)
        notification = @session.written
        assert_equal 12345, notification.params[:progressToken]
      end

      test "progress notification values can be any numeric type" do
        test_cases = [
          { progress: 0, description: "zero" },
          { progress: 50, description: "integer" },
          { progress: 0.5, description: "decimal" },
          { progress: 0.001, description: "small decimal" },
          { progress: 100.0, description: "large integer as float" }
        ]

        test_cases.each do |test_case|
          @handler.send_progress_notification(
            progressToken: "value_test",
            progress: test_case[:progress]
          )

          notification = @session.written
          assert_equal test_case[:progress], notification.params[:progress],
                       "Failed for #{test_case[:description]}"
        end
      end

      test "progress notification with nil values excludes optional fields" do
        @handler.send_progress_notification(
          progressToken: "nil_test",
          progress: 50,
          total: nil,
          message: nil
        )

        notification = @session.written
        params = notification.params
        assert_equal "nil_test", params[:progressToken]
        assert_equal 50, params[:progress]
        refute params.key?(:total), "nil total should not be included"
        refute params.key?(:message), "nil message should not be included"
      end

      test "progress notification sequence with increasing values" do
        notifications = []

        @session.instance_eval do
          @all_written = []

          def write(data)
            @all_written << data
            super
          end

          def all_written
            @all_written
          end
        end

        # Send a sequence of progress notifications (spec requires increasing progress)
        @handler.send_progress_notification(progressToken: "sequence", progress: 0, total: 100, message: "Starting...")
        @handler.send_progress_notification(progressToken: "sequence", progress: 25, total: 100, message: "25% complete")
        @handler.send_progress_notification(progressToken: "sequence", progress: 50, total: 100, message: "Halfway there")
        @handler.send_progress_notification(progressToken: "sequence", progress: 75, total: 100)
        @handler.send_progress_notification(progressToken: "sequence", progress: 100, total: 100, message: "Complete!")

        all_notifications = @session.all_written
        assert_equal 5, all_notifications.length

        # Verify sequence meets spec requirement: "progress value MUST increase with each notification"
        progress_values = all_notifications.map { |n| n.params[:progress] }
        assert_equal [ 0, 25, 50, 75, 100 ], progress_values, "Progress values must increase"

        # Verify messages
        messages = all_notifications.map { |n| n.params[:message] }.compact
        assert_equal [ "Starting...", "25% complete", "Halfway there", "Complete!" ], messages
      end

      test "progress notification JSON serialization complies with 2025-03-26 spec" do
        @handler.send_progress_notification(
          progressToken: "json_test",
          progress: 42,
          total: 100,
          message: "JSON formatting test"
        )

        notification = @session.written

        # Verify JSON serialization
        json_string = notification.to_json
        parsed = JSON.parse(json_string)

        assert_equal "2.0", parsed["jsonrpc"]
        assert_equal "notifications/progress", parsed["method"]
        assert_nil parsed["id"], "Notifications should not have id field"

        params = parsed["params"]
        assert_equal "json_test", params["progressToken"]
        assert_equal 42, params["progress"]
        assert_equal 100, params["total"]
        assert_equal "JSON formatting test", params["message"]
      end

      test "progress notification handles special characters in message" do
        special_messages = [
          "Progress: 50% complete",
          "File: \"example.txt\"",
          "Path: C:\\Users\\test\\",
          "Unicode: 🚀 ✨ 📊",
          "Multi\nline\ntext",
          "Tabs\tand\tspaces",
          "Forward/slash\\backslash"
        ]

        special_messages.each do |message|
          @handler.send_progress_notification(
            progressToken: "encoding_test",
            progress: 50,
            total: 100,
            message: message
          )

          notification = @session.written

          # Verify round-trip through JSON
          json_string = notification.to_json
          parsed = JSON.parse(json_string)

          assert_equal message, parsed["params"]["message"],
                       "Message encoding failed for: #{message.inspect}"
        end
      end

      test "backward compatibility for deprecated token/value parameters" do
        # Test that the old method signature still works with deprecation warning
        logs = []

        # Create a custom logger to capture warnings
        test_logger = Logger.new(StringIO.new)
        test_logger.instance_eval do
          @captured_logs = []

          def warn(message)
            @captured_logs << message
            super
          end

          def captured_logs
            @captured_logs
          end
        end

        # Replace Rails.logger temporarily
        original_logger = Rails.logger
        Rails.logger = test_logger

        begin
          @handler.send_progress_notification_legacy(token: "old_style", value: 0.8, message: "Backward compatible")

          notification = @session.written
          assert_equal "notifications/progress", notification.method

          params = notification.params
          assert_equal "old_style", params[:progressToken]
          assert_equal 0.8, params[:progress]
          assert_equal "Backward compatible", params[:message]

          # Verify deprecation warning was logged
          assert test_logger.captured_logs.any? { |log| log.include?("DEPRECATION") && log.include?("token/value is deprecated") }
        ensure
          Rails.logger = original_logger
        end
      end

      test "progress notification with metadata dictionary" do
        # The 2025 spec allows including a progressToken in request metadata
        request_with_meta = {
          jsonrpc: "2.0",
          id: 1,
          method: "some_method",
          params: {
            _meta: {
              progressToken: "meta_test_token"
            }
          }
        }

        # When server sends progress notification, it should use the same token
        @handler.send_progress_notification(
          progressToken: "meta_test_token",
          progress: 0.3,
          total: 1,
          message: "Processing request"
        )

        notification = @session.written
        assert_equal "meta_test_token", notification.params[:progressToken]
        assert_equal 0.3, notification.params[:progress]
        assert_equal 1, notification.params[:total]
        assert_equal "Processing request", notification.params[:message]
      end
    end
  end
end
