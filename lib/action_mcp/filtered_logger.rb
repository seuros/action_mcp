# frozen_string_literal: true

module ActionMCP
  # Custom logger that filters out repetitive MCP requests
  class FilteredLogger < ActiveSupport::Logger
    FILTERED_PATHS = [].freeze

    FILTERED_METHODS = [
      "notifications/initialized",
      "notifications/ping"
    ].freeze

    def add(severity, message = nil, progname = nil, &block)
      # Filter out specific paths
      if message.is_a?(String)
        return if FILTERED_PATHS.any? { |path| message.include?(path) && message.include?("200 OK") }

        # Filter out repetitive MCP notifications
        return if FILTERED_METHODS.any? { |method| message.include?(method) }
      end

      super
    end
  end
end
