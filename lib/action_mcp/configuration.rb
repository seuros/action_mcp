# frozen_string_literal: true

module ActionMCP
  # Configuration class to hold settings for the ActionMCP server.
  class Configuration
    attr_accessor :name, :version, :logging_enabled

    def initialize
      # Use Rails.application values if available, or fallback to defaults.
      @name = defined?(Rails) && Rails.respond_to?(:application) && Rails.application.respond_to?(:name) ? Rails.application.name : "ActionMCP"
      @version = defined?(Rails) && Rails.respond_to?(:application) && Rails.application.respond_to?(:version) ? Rails.application.version.to_s.presence : "0.0.1"
      @logging_enabled = true
    end
  end
end
