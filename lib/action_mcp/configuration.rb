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
    attr_accessor :logging_enabled,
                  :list_changed,
                  :resources_subscribe,
                  :logging_level,
                  :active_profile,
                  :profiles,
                  # --- New Transport Options ---
                  :mcp_endpoint_path,
                  :sse_heartbeat_interval,
                  :post_response_preference # :json or :sse

    def initialize
      @logging_enabled = true
      @list_changed = false
      @logging_level = :info
      @resources_subscribe = false
      @active_profile = :primary
      @profiles = default_profiles

      @mcp_endpoint_path = "/mcp"
      @sse_heartbeat_interval = 30
      @post_response_preference = :json
    end

    def name
      @name || Rails.application.name
    end

    def version
      @version || (has_rails_version ? Rails.application.version.to_s : "0.0.1")
    end

    # Get active profile (considering thread-local override)
    def active_profile
      ActionMCP.thread_profiles.value || @active_profile
    end

    # Load custom profiles from Rails configuration
    def load_profiles
      # First load defaults from the gem
      @profiles = default_profiles

      # Try to load from config/mcp.yml in the Rails app using Rails.config_for
      begin
        app_config = Rails.application.config_for(:mcp)

        raise "Invalid MCP config file" unless app_config.is_a?(Hash)

        # Merge with defaults so user config overrides gem defaults
        @profiles = app_config
      rescue StandardError
        # If the config file doesn't exist in the Rails app, just use the defaults
        Rails.logger.debug "No MCP config found in Rails app, using defaults from gem"
      end

      # Apply the active profile
      use_profile(@active_profile)

      self
    end

    # Switch to a specific profile
    def use_profile(profile_name)
      profile_name = profile_name.to_sym
      unless @profiles.key?(profile_name)
        Rails.logger.warn "Profile '#{profile_name}' not found, using primary"
        profile_name = :primary
      end

      @active_profile = profile_name
      apply_profile_options

      self
    end

    # Filter tools based on active profile
    def filtered_tools
      return ToolsRegistry.non_abstract if should_include_all?(:tools)

      tool_names = @profiles[active_profile][:tools] || []
      # Convert tool names to underscored format
      tool_names = tool_names.map { |name| name.to_s.underscore }
      ToolsRegistry.non_abstract.select { |tool| tool_names.include?(tool.name.underscore) }
    end

    # Filter prompts based on active profile
    def filtered_prompts
      return PromptsRegistry.non_abstract if should_include_all?(:prompts)

      prompt_names = @profiles[active_profile][:prompts] || []
      PromptsRegistry.non_abstract.select { |prompt| prompt_names.include?(prompt.name) }
    end

    # Filter resources based on active profile
    def filtered_resources
      return ResourceTemplatesRegistry.non_abstract if should_include_all?(:resources)

      resource_names = @profiles[active_profile][:resources] || []
      ResourceTemplatesRegistry.non_abstract.select { |resource| resource_names.include?(resource.name) }
    end

    # Returns capabilities based on active profile
    def capabilities
      capabilities = {}

      # Only include capabilities if the corresponding filtered registry is non-empty
      capabilities[:tools] = { listChanged: @list_changed } if filtered_tools.any?

      capabilities[:prompts] = { listChanged: @list_changed } if filtered_prompts.any?

      capabilities[:logging] = {} if @logging_enabled

      capabilities[:resources] = { subscribe: @resources_subscribe } if filtered_resources.any?

      capabilities
    end

    def apply_profile_options
      profile = @profiles[active_profile]
      return unless profile && profile[:options]

      options = profile[:options]
      @list_changed = options[:list_changed] unless options[:list_changed].nil?
      @logging_enabled = options[:logging_enabled] unless options[:logging_enabled].nil?
      @logging_level = options[:logging_level] unless options[:logging_level].nil?
      @resources_subscribe = options[:resources_subscribe] unless options[:resources_subscribe].nil?
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

    def should_include_all?(type)
      return false unless @profiles[active_profile]

      items = @profiles[active_profile][type]
      # Return true ONLY if items contains "all"
      items&.include?("all")
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
    attr_accessor :logger

    # Thread-local storage for active profiles
    def thread_profiles
      @thread_profiles ||= Concurrent::ThreadLocalVar.new(nil)
    end

    # Returns the configuration instance.
    def configuration
      @configuration ||= Configuration.new
    end

    # Configures the ActionMCP module.
    def configure
      yield(configuration)
    end

    def with_profile(profile_name)
      previous_profile = thread_profiles.value
      thread_profiles.value = profile_name

      # Apply the profile options when switching profiles
      configuration&.apply_profile_options

      yield if block_given?
    ensure
      thread_profiles.value = previous_profile if block_given?

      # Reapply the previous profile's options when switching back
      configuration.apply_profile_options if block_given? && configuration
    end
  end
end
