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
    attr_writer :name, :version
    attr_accessor :logging_enabled, # This is not working yet
                  :list_changed, # This is not working yet
                  :resources_subscribe, # This is not working yet
                  :logging_level # This is not working yet

    # Initializes a new Configuration instance.
    #
    # @return [void]

    def initialize
      @logging_enabled = true
      @list_changed = false
      @logging_level = :info
    end

    def name
      @name || Rails.application.name
    end

    def version
      @version || (has_rails_version ? Rails.application.version.to_s : "0.0.1")
    end

    # Returns a hash of capabilities.
    #
    # @return [Hash] A hash containing the resources capabilities.
    def capabilities
      capabilities = {}
      # Only include each capability if the corresponding registry is non-empty.
      capabilities[:tools] = { listChanged: false } if ToolsRegistry.non_abstract.any?
      capabilities[:prompts] = { listChanged: false } if PromptsRegistry.non_abstract.any?
      capabilities[:logging] = {} if @logging_enabled
      # For now, we only have one type of resource, ResourceTemplate
      # For Resources, we need to think about how to pass the list to the session.
      capabilities[:resources] = {} if ResourceTemplatesRegistry.non_abstract.any?
      capabilities
    end

    private

    def has_rails_version
      gem "rails_app_version"
      require "rails_app_version/railtie"
      true
    rescue LoadError
      false
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
