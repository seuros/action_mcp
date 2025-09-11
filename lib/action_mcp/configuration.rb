# frozen_string_literal: true

require_relative "gateway"
require "active_support/core_ext/integer/time"

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
                  :elicitation_enabled,
                  :verbose_logging,
                  # --- Authentication Options ---
                  :authentication_methods,
                  # --- Transport Options ---
                  :sse_heartbeat_interval,
                  :post_response_preference, # :json or :sse
                  :protocol_version,
                  # --- SSE Resumability Options ---
                  :sse_event_retention_period,
                  :max_stored_sse_events,
                  # --- Gateway Options ---
                  :gateway_class,
                  # --- Session Store Options ---
                  :session_store_type,
                  :client_session_store_type,
                  :server_session_store_type,
                  # --- Pub/Sub and Thread Pool Options ---
                  :adapter,
                  :min_threads,
                  :max_threads,
                  :max_queue,
                  :polling_interval,
                  :connects_to

    def initialize
      @logging_enabled = false
      @list_changed = true
      @logging_level = :warning
      @resources_subscribe = false
      @elicitation_enabled = false
      @verbose_logging = false
      @active_profile = :primary
      @profiles = default_profiles

      # Authentication defaults - empty means all configured identifiers will be tried
      @authentication_methods = []

      @sse_heartbeat_interval = 30
      @post_response_preference = :json
      @protocol_version = "2025-03-26" # Default to legacy for backwards compatibility

      # Resumability defaults
      @sse_event_retention_period = 15.minutes
      @max_stored_sse_events = 100

      # Gateway - default to ApplicationGateway if it exists, otherwise ActionMCP::Gateway
      @gateway_class = defined?(::ApplicationGateway) ? ::ApplicationGateway : ActionMCP::Gateway
      @gateway_class_name = nil

      # Session Store
      @session_store_type = Rails.env.production? ? :active_record : :volatile
      @client_session_store_type = nil # defaults to session_store_type
      @server_session_store_type = nil # defaults to session_store_type
    end

    def name
      @name || Rails.application.name
    end

    def version
      @version || (has_rails_version ? Rails.application.version.to_s : "0.0.1")
    end

    def gateway_class
      if @gateway_class_name
        @gateway_class_name.constantize

      else
        @gateway_class
      end
    end

    # Get active profile (considering thread-local override)
    def active_profile
      ActionMCP.thread_profiles.value || @active_profile
    end

    # Load custom configuration from Rails configuration
    def load_profiles
      # First load defaults from the gem
      @profiles = default_profiles

      # Preserve any settings that were already set via Rails config
      preserved_name = @name

      # Try to load from config/mcp.yml in the Rails app using Rails.config_for
      begin
        app_config = Rails.application.config_for(:mcp)

        raise "Invalid MCP config file" unless app_config.is_a?(Hash)

        # Extract authentication configuration if present
        # Handle both symbol and string keys
        @authentication_methods = Array(app_config[:authentication] || app_config["authentication"]) if app_config[:authentication] || app_config["authentication"]

        # Extract other top-level configuration settings
        extract_top_level_settings(app_config)

        # Extract profiles configuration - merge with defaults instead of replacing
        # Rails.config_for returns OrderedOptions which uses symbol keys
        if app_config[:profiles] || app_config["profiles"]
          # Get profiles with either symbol or string key
          app_profiles = app_config[:profiles] || app_config["profiles"]

          # Convert to regular hash and deep symbolize keys
          if app_profiles.is_a?(ActiveSupport::OrderedOptions)
            app_profiles = app_profiles.to_h.deep_symbolize_keys
          elsif app_profiles.respond_to?(:deep_symbolize_keys)
            app_profiles = app_profiles.deep_symbolize_keys
          end

          Rails.logger.debug "[Configuration] Merging profiles: #{app_profiles.inspect}"
          @profiles = @profiles.deep_merge(app_profiles)
        end
      rescue StandardError => e
        # If the config file doesn't exist in the Rails app, just use the defaults
        Rails.logger.warn "[Configuration] Failed to load MCP config: #{e.class} - #{e.message}"
        # No MCP config found in Rails app, using defaults from gem
      end

      # Apply the active profile
      Rails.logger.info "[ActionMCP] Loaded profiles: #{@profiles.keys.join(', ')}"
      Rails.logger.info "[ActionMCP] Using profile: #{@active_profile}"
      use_profile(@active_profile)

      # Restore preserved settings
      @name = preserved_name if preserved_name

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
      profile = @profiles[active_profile]

      Rails.logger.debug "[ActionMCP] Generating capabilities for profile: #{active_profile}"
      Rails.logger.debug "[ActionMCP] Profile config: #{profile.inspect}"

      # Check profile configuration instead of registry contents
      # If profile includes tools (either "all" or specific tools), advertise tools capability
      capabilities[:tools] = { listChanged: @list_changed } if profile && profile[:tools]&.any?

      # If profile includes prompts, advertise prompts capability
      capabilities[:prompts] = { listChanged: @list_changed } if profile && profile[:prompts]&.any?

      capabilities[:logging] = {} if @logging_enabled

      # If profile includes resources, advertise resources capability
      if profile && profile[:resources]&.any?
        capabilities[:resources] = { subscribe: @resources_subscribe, listChanged: @list_changed }
      end

      capabilities[:elicitation] = {} if @elicitation_enabled

      capabilities
    end

    # Get effective client session store type (falls back to global session_store_type)
    def client_session_store_type
      @client_session_store_type || @session_store_type
    end

    # Get effective server session store type (falls back to global session_store_type)
    def server_session_store_type
      @server_session_store_type || @session_store_type
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

    def eager_load_if_needed
      profile = @profiles[active_profile]
      return unless profile

      # Check if any component type includes "all"
      needs_eager_load = profile[:tools]&.include?("all") ||
                         profile[:prompts]&.include?("all") ||
                         profile[:resources]&.include?("all")

      return unless needs_eager_load

      ensure_mcp_components_loaded
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
            logging_enabled: false,
            logging_level: :warning,
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

    def extract_top_level_settings(app_config)
      # Create a wrapper that handles both symbol and string keys
      config = HashWithIndifferentAccess.new(app_config)

      # Extract adapter configuration
      if config["adapter"]
        # This will be handled by the pub/sub system, we just store it for now
        @adapter = config["adapter"]
      end

      # Extract thread pool settings
      @min_threads = config["min_threads"] if config["min_threads"]

      @max_threads = config["max_threads"] if config["max_threads"]

      @max_queue = config["max_queue"] if config["max_queue"]

      # Extract polling interval for solid_cable
      @polling_interval = config["polling_interval"] if config["polling_interval"]

      # Extract connects_to setting
      @connects_to = config["connects_to"] if config["connects_to"]

      # Extract verbose logging setting
      @verbose_logging = config["verbose_logging"] if app_config.key?("verbose_logging")

      # Extract gateway class configuration
      @gateway_class_name = config["gateway_class"] if config["gateway_class"]

      # Extract active profile setting
      @active_profile = config["profile"].to_sym if config["profile"]

      # Extract session store configuration
      @session_store_type = config["session_store_type"].to_sym if config["session_store_type"]

      # Extract client and server session store types
      if config["client_session_store_type"]
        @client_session_store_type = config["client_session_store_type"].to_sym
      end

      return unless config["server_session_store_type"]

      @server_session_store_type = config["server_session_store_type"].to_sym
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

    def ensure_mcp_components_loaded
      # Only load if we haven't loaded yet - but in development, always reload
      return if @mcp_components_loaded && !Rails.env.development?

      # Use Zeitwerk eager loading if available (in to_prepare phase)
      mcp_path = Rails.root.join("app/mcp")
      if mcp_path.exist? && Rails.autoloaders.main.respond_to?(:eager_load_dir)
        # This will trigger all inherited hooks properly
        Rails.autoloaders.main.eager_load_dir(mcp_path)
      elsif mcp_path.exist?
        # Fallback for initialization phase - use require_dependency
        # Load base classes first in specific order
        base_files = [
          mcp_path.join("application_gateway.rb"),
          mcp_path.join("tools/application_mcp_tool.rb"),
          mcp_path.join("prompts/application_mcp_prompt.rb"),
          mcp_path.join("resource_templates/application_mcp_res_template.rb"),
          # Load ArithmeticTool before other tools that inherit from it
          mcp_path.join("tools/arithmetic_tool.rb")
        ]

        base_files.each do |file|
          require_dependency file.to_s if file.exist?
        end

        # Then load all other files
        Dir.glob(mcp_path.join("**/*.rb")).sort.each do |file|
          # Skip base classes we already loaded
          next if base_files.any? { |base| file == base.to_s }

          require_dependency file
        end
      end
      @mcp_components_loaded = true unless Rails.env.development?
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
