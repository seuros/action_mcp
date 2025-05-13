# frozen_string_literal: true

module ActionMCP
  class LogSubscriber < ActiveSupport::LogSubscriber
    # Thread-local storage for additional metrics
    class << self
      attr_accessor :custom_metrics, :subscribed_events, :formatters, :metric_groups
    end

    def self.reset_runtime
      # Get the combined runtime from both tool and prompt operations
      tool_rt = Thread.current[:mcp_tool_runtime] || 0
      prompt_rt = Thread.current[:mcp_prompt_runtime] || 0
      total_rt = tool_rt + prompt_rt

      # Reset both counters
      Thread.current[:mcp_tool_runtime] = 0
      Thread.current[:mcp_prompt_runtime] = 0

      # Return the total runtime
      total_rt
    end

    def tool_call(event)
      Thread.current[:mcp_tool_runtime] ||= 0
      Thread.current[:mcp_tool_runtime] += event.duration
    end

    def prompt_call(event)
      Thread.current[:mcp_prompt_runtime] ||= 0
      Thread.current[:mcp_prompt_runtime] += event.duration
    end

    # Add a custom metric to be included in logs
    def self.add_metric(name, value)
      self.custom_metrics ||= {}
      self.custom_metrics[name] = value
    end

    # Measure execution time of a block and add as metric
    def self.measure_metric(name)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000.0

      add_metric(name, duration)
      result
    end

    # Reset all custom metrics
    def self.reset_metrics
      self.custom_metrics = nil
    end

    # Subscribe to a Rails event to capture metrics
    # @param pattern [String] Event name pattern (e.g., "sql.active_record")
    # @param metric_name [Symbol] Name to use for the metric
    # @param options [Hash] Options for capturing the metric
    def self.subscribe_event(pattern, metric_name, options = {})
      self.subscribed_events ||= {}

      # Store subscription info
      self.subscribed_events[pattern] = {
        metric_name: metric_name,
        options: options
      }

      # Create the actual subscription
      ActiveSupport::Notifications.subscribe(pattern) do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)

        # Extract value based on options
        value = if options[:duration]
                  event.duration
        elsif options[:extract_value].respond_to?(:call)
                  options[:extract_value].call(event)
        else
                  1 # Default to count
        end

        # Accumulate or set the metric
        if options[:accumulate]
          self.custom_metrics ||= {}
          self.custom_metrics[metric_name] ||= 0
          self.custom_metrics[metric_name] += value
        else
          add_metric(metric_name, value)
        end
      end
    end

    # Format metrics for display in logs
    def self.format_metrics
      return nil if custom_metrics.nil? || custom_metrics.empty?

      # If grouping is enabled, organize metrics by groups
      if metric_groups.present?
        grouped_metrics = {}

        # Initialize groups with empty arrays
        metric_groups.each_key do |group_name|
          grouped_metrics[group_name] = []
        end

        # Add "other" group for ungrouped metrics
        grouped_metrics[:other] = []

        # Assign metrics to their groups
        custom_metrics.each do |key, value|
          group = nil

          # Find which group this metric belongs to
          metric_groups.each do |group_name, metrics|
            if metrics.include?(key)
              group = group_name
              break
            end
          end

          # Format the metric
          formatter = formatters&.dig(key)
          formatted_value = if formatter.respond_to?(:call)
                              formatter.call(value)
          elsif value.is_a?(Float)
                              format("%.1fms", value)
          else
                              value.to_s
          end

          formatted_metric = "#{key}: #{formatted_value}"

          # Add to appropriate group (or "other")
          if group
            grouped_metrics[group] << formatted_metric
          else
            grouped_metrics[:other] << formatted_metric
          end
        end

        # Join metrics within groups, then join groups
        grouped_metrics.map do |_group, metrics|
          next if metrics.empty?

          metrics.join(" | ")
        end.compact.join(" | ")
      else
        # No grouping, just format all metrics
        custom_metrics.map do |key, value|
          formatter = formatters&.dig(key)
          formatted_value = if formatter.respond_to?(:call)
                              formatter.call(value)
          elsif value.is_a?(Float)
                              format("%.1fms", value)
          else
                              value.to_s
          end
          "#{key}: #{formatted_value}"
        end.join(" | ")
      end
    end

    # Register a custom formatter for a specific metric
    # @param metric_name [Symbol] The name of the metric
    # @param block [Proc] The formatter block that takes the value and returns a string
    def self.register_formatter(metric_name, &block)
      self.formatters ||= {}
      self.formatters[metric_name] = block
    end

    # Define a group of related metrics
    # @param group_name [Symbol] The name of the metric group
    # @param metrics [Array<Symbol>] The metrics that belong to this group
    def self.define_metric_group(group_name, metrics)
      self.metric_groups ||= {}
      self.metric_groups[group_name] = metrics
    end

    # Enhance process_action to include our custom metrics
    def process_action(event)
      return unless logger.info?

      return unless self.class.custom_metrics.present?

      metrics_msg = self.class.format_metrics
      event.payload[:message] = "#{event.payload[:message]} | #{metrics_msg}" if metrics_msg
      self.class.reset_metrics
    end

    attach_to :action_mcp
  end
end
