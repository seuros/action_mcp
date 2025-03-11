# frozen_string_literal: true

module ActionMCP
  # Configuration class to hold settings for the ActionMCP server.
  class Configuration
    # @!attribute name
    #   @return [String] The name of the MCP Server.
    # @!attribute version
    #   @return [String] The version of the MCP Server.
    # @!attribute logging_enabled
    #   @return [Boolean] Whether logging is enabled.
    # @!attribute list_changed
    #   @return [Boolean] Whether to send a listChanged notification for tools, prompts, and resources.
    # @!attribute resources_subscribe
    #   @return [Boolean] Whether to subscribe to resources.
    # @!attribute logging_level
    #   @return [Symbol] The logging level.
    attr_accessor :name, :version, :logging_enabled,
                  # Right now, if enabled, the server will send a listChanged notification for tools, prompts, and resources.
                  # We can make it more granular in the future, but for now, it's a simple boolean.
                  :list_changed,
                  :resources_subscribe,
                  :logging_level

    # Initializes a new Configuration instance.
    #
    # @return [void]
    def initialize
      # Use Rails.application values if available, or fallback to defaults.
      @name = defined?(Rails) && Rails.respond_to?(:application) && Rails.application.respond_to?(:name) ? Rails.application.name : "ActionMCP"
      @version = defined?(Rails) && Rails.respond_to?(:application) && Rails.application.respond_to?(:version) ? Rails.application.version.to_s.presence : "0.0.1"
      @logging_enabled = true
      @list_changed = false
      @logging_level = :info
    end

    # Returns a hash of capabilities.
    #
    # @return [Hash] A hash containing the resources capabilities.
    def capabilities
      capabilities = {}
      # Only include each capability if the corresponding registry is non-empty.
      capabilities[:tools] = { listChanged: @list_changed } if ToolsRegistry.non_abstract.any?
      capabilities[:prompts] = { listChanged: @list_changed } if PromptsRegistry.non_abstract.any?
      capabilities[:logging] = {} if @logging_enabled
      # capabilities[:resources] = { subscribe: @resources_subscribe,
      #                              listChanged: @list_changed }.compact
      { capabilities: capabilities }
    end
  end

  class << self
    attr_accessor :server
    # Returns the configuration instance.
    #
    # @return [Configuration] the configuration instance
    def configuration
      @configuration ||= Configuration.new
    end

    # Configures the ActionMCP module.
    #
    # @yield [configuration] the configuration instance
    # @return [void]
    def configure
      yield(configuration)
    end
  end
end
