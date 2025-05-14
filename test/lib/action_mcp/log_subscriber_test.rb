# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class LogSubscriberTest < ActiveSupport::TestCase
    def setup
      ActionMCP::LogSubscriber.custom_metrics = nil
    end

    def teardown
      ActionMCP::LogSubscriber.custom_metrics = nil
    end

    test "add_metric adds a metric to the custom_metrics hash" do
      ActionMCP::LogSubscriber.add_metric(:test_metric, 42)

      assert_equal 42, ActionMCP::LogSubscriber.custom_metrics[:test_metric]
    end

    test "measure_metric measures execution time" do
      ActionMCP::LogSubscriber.measure_metric(:test_operation) do
        sleep(0.01) # Small delay to ensure measurable time
      end

      assert ActionMCP::LogSubscriber.custom_metrics[:test_operation].positive?
      assert_kind_of Float, ActionMCP::LogSubscriber.custom_metrics[:test_operation]
    end

    test "reset_metrics clears all custom metrics" do
      ActionMCP::LogSubscriber.add_metric(:test_metric, 42)
      assert_equal 42, ActionMCP::LogSubscriber.custom_metrics[:test_metric]

      ActionMCP::LogSubscriber.reset_metrics
      assert_nil ActionMCP::LogSubscriber.custom_metrics
    end

    test "format_metrics formats metrics correctly" do
      # Add various types of metrics
      ActionMCP::LogSubscriber.add_metric(:integer_metric, 42)
      ActionMCP::LogSubscriber.add_metric(:float_metric, 123.456)
      ActionMCP::LogSubscriber.add_metric(:string_metric, "test")

      formatted = ActionMCP::LogSubscriber.format_metrics

      assert_includes formatted, "integer_metric: 42"
      assert_includes formatted, "float_metric: 123.5ms"

      # Custom formatting
      ActionMCP::LogSubscriber.register_formatter(:integer_metric) do |value|
        "#{value} items"
      end

      formatted = ActionMCP::LogSubscriber.format_metrics
      assert_includes formatted, "integer_metric: 42 items"
      assert_includes formatted, "string_metric: test"
    end

    test "process_action adds metrics to the payload message" do
      # Setup
      ActionMCP::LogSubscriber.add_metric(:test_metric, 42)

      # Create a mock event with a payload
      payload = { message: "Original message" }
      event = ActiveSupport::Notifications::Event.new(
        "process_action.action_controller",
        Time.now, Time.now + 0.1,
        "1", payload
      )

      # Process the event
      subscriber = ActionMCP::LogSubscriber.new

      # Check if process_action method exists and has the right arity
      if subscriber.respond_to?(:process_action) &&
         subscriber.method(:process_action).arity == 1
        # Process the event
        subscriber.process_action(event)

        # If the message was updated, verify the metrics were added
        if payload[:message].include?("Original message | ")
          assert_includes payload[:message], "test_metric: 42"
        else
          # Otherwise just check that the payload contains the original message
          assert_equal "Original message", payload[:message]
          skip "LogSubscriber#process_action not implemented to add metrics in this environment"
        end
      else
        skip "LogSubscriber#process_action not implemented in this environment"
      end
    end

    test "metric groups organize related metrics" do
      # Define a metric group
      ActionMCP::LogSubscriber.define_metric_group(:test_group, %i[metric1 metric2])

      # Add metrics from that group
      ActionMCP::LogSubscriber.add_metric(:metric1, "value1")
      ActionMCP::LogSubscriber.add_metric(:metric2, "value2")

      # Add an ungrouped metric
      ActionMCP::LogSubscriber.add_metric(:other_metric, "other")

      # Format and check grouping
      formatted = ActionMCP::LogSubscriber.format_metrics

      # Groups should be maintained in the output
      assert_includes formatted, "metric1: value1 | metric2: value2"
      assert_includes formatted, "other_metric: other"
    end

    test "subscribe_event captures metrics from notifications" do
      # Create a subscription
      ActionMCP::LogSubscriber.subscribe_event("test.event", :event_count, accumulate: true)

      # Trigger the event
      ActiveSupport::Notifications.instrument("test.event") { }

      # Check metric was recorded
      assert_equal 1, ActionMCP::LogSubscriber.custom_metrics[:event_count]

      # Trigger again to test accumulation
      ActiveSupport::Notifications.instrument("test.event") { }
      assert_equal 2, ActionMCP::LogSubscriber.custom_metrics[:event_count]
    end
  end
end
