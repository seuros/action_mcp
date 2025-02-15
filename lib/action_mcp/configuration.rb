# frozen_string_literal: true

module ActionMCP
  # Configuration class to hold settings for the ActionMCP server.
  class Configuration
    attr_accessor :name, :version, :logging_enabled,
                  # Right now, if enabled, the server will send a listChanged notification for tools, prompts, and resources.
                  # We can make it more granular in the future, but for now, it's a simple boolean.
                  :list_changed,
                  :resources_subscribe

    def initialize
      # Use Rails.application values if available, or fallback to defaults.
      @name = defined?(Rails) && Rails.respond_to?(:application) && Rails.application.respond_to?(:name) ? Rails.application.name : "ActionMCP"
      @version = defined?(Rails) && Rails.respond_to?(:application) && Rails.application.respond_to?(:version) ? Rails.application.version.to_s.presence : "0.0.1"
      @logging_enabled = true
      @list_changed = false
    end
  end
end
