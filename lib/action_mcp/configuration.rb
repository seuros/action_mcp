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
    #   @return [Symbol] The logging level.    attr_writer :name, :version
    attr_writer :name, :version
    attr_accessor :logging_enabled,
                  :list_changed,
                  :resources_subscribe,
                  :logging_level,
                  :active_profile,
                  :profiles

    def initialize
      @logging_enabled = true
      @list_changed = false
      @logging_level = :info
      @resources_subscribe = false
      @active_profile = :primary
      @profiles = default_profiles
    end

    def name
      @name || Rails.application.name
    end

    def version
      @version || (has_rails_version ? Rails.application.version.to_s : "0.0.1")
    end

    # Load custom profiles from Rails configuration
    def load_profiles
      # First load defaults from the gem
      @profiles = default_profiles

      # Then try to load from config/mcp.yml in the Rails app
      config_path = Rails.root.join("config", "mcp.yml")
      if File.exist?(config_path)
        begin
          yaml_content = YAML.safe_load(File.read(config_path), symbolize_names: true)
          # Merge with defaults so user config overrides gem defaults
          @profiles.deep_merge!(yaml_content) if yaml_content
        rescue StandardError => e
          Rails.logger.error "Failed to load MCP profiles from #{config_path}: #{e.message}"
        end
      end

      # Apply the active profile
      use_profile(@active_profile)

      self
    end

    # Switch to a specific profile
    def use_profile(profile_name)
      profile_name = profile_name.to_sym
      unless @profiles.key?(profile_name)
        Rails.logger.warn "Profile '#{profile_name}' not found, using default"
        profile_name = :default
      end

      @active_profile = profile_name
      apply_profile_options

      self
    end

    # Filter tools based on active profile
    def filtered_tools
      return ToolsRegistry.non_abstract if should_include_all?(:tools)

      tool_names = @profiles[@active_profile][:tools] || []
      # Convert tool names to underscored format
      tool_names = tool_names.map { |name| name.to_s.underscore }
      ToolsRegistry.non_abstract.select { |tool| tool_names.include?(tool.name.underscore) }
    end

    # Filter prompts based on active profile
    def filtered_prompts
      return PromptsRegistry.non_abstract if should_include_all?(:prompts)

      prompt_names = @profiles[@active_profile][:prompts] || []
      PromptsRegistry.non_abstract.select { |prompt| prompt_names.include?(prompt.name) }
    end

    # Filter resources based on active profile
    def filtered_resources
      return ResourceTemplatesRegistry.non_abstract if should_include_all?(:resources)

      resource_names = @profiles[@active_profile][:resources] || []
      ResourceTemplatesRegistry.non_abstract.select { |resource| resource_names.include?(resource.name) }
    end

    # Returns capabilities based on active profile
    def capabilities
      capabilities = {}
      # Only include each capability if the corresponding filtered registry is non-empty
      capabilities[:tools] = { listChanged: @list_changed } if filtered_tools.any?
      capabilities[:prompts] = { listChanged: @list_changed } if filtered_prompts.any?
      capabilities[:logging] = {} if @logging_enabled
      capabilities[:resources] = { subscribe: @resources_subscribe } if filtered_resources.any?
      capabilities
    end

    private

    def default_profiles
      {
        primary: {
          tools: [ "all" ],
          prompts: [ "all" ],
          resources: [ "all" ],
          options: {
            list_changed: false,
            logging_enabled: true,
            logging_level: :info,
            resources_subscribe: false
          }
        },
        minimal: {
          tools: [],
          prompts: [],
          resources: [],
          options: {
            list_changed: false,
            logging_enabled: false,
            logging_level: :warn,
            resources_subscribe: false
          }
        }
      }
    end

    def apply_profile_options
      profile = @profiles[@active_profile]
      return unless profile && profile[:options]

      options = profile[:options]
      @list_changed = options[:list_changed] unless options[:list_changed].nil?
      @logging_enabled = options[:logging_enabled] unless options[:logging_enabled].nil?
      @logging_level = options[:logging_level] unless options[:logging_level].nil?
      @resources_subscribe = options[:resources_subscribe] unless options[:resources_subscribe].nil?
    end

    def should_include_all?(type)
      return true unless @profiles[@active_profile]

      items = @profiles[@active_profile][type]
      items.nil? || items.include?("all")
    end

    def has_rails_version
      gem "rails_app_version"
      require "rails_app_version/railtie"
      true
    rescue LoadError
      false
    end
  end

  class << self
    attr_accessor :server, :logger

    # Returns the configuration instance.
    def configuration
      @configuration ||= Configuration.new
    end

    # Configures the ActionMCP module.
    def configure
      yield(configuration)
    end

    # Temporarily use a different profile
    def with_profile(profile_name)
      previous_profile = configuration.active_profile
      configuration.use_profile(profile_name)

      yield if block_given?
    ensure
      configuration.use_profile(previous_profile) if block_given?
    end
  end
end
