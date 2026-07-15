# frozen_string_literal: true

require "rails"
require "active_model/railtie"
require "jsonrpc-rails"

module ActionMCP
  # Engine for integrating ActionMCP with Rails applications.
  class Engine < ::Rails::Engine
    isolate_namespace ActionMCP

    def self.endpoint_path_matcher(path)
      endpoint = ActionDispatch::Journey::Router::Utils.normalize_path(path)
      formatted_endpoint = /\A#{Regexp.escape(endpoint)}(?:\.[^\/.]+)?\z/

      lambda do |request_path|
        normalized_path = ActionDispatch::Journey::Router::Utils.normalize_path(request_path)
        formatted_endpoint.match?(normalized_path)
      end
    end

    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym "MCP"
    end

    # Provide a configuration namespace for ActionMCP
    config.action_mcp = ActionMCP.configuration

    # Create the ActiveSupport load hooks
    ActiveSupport.on_load(:action_mcp_tool) do
      # Register the tool when it's loaded
      ActionMCP::ToolsRegistry.register(self) unless abstract?
    end

    ActiveSupport.on_load(:action_mcp_prompt) do
      # Register the prompt when it's loaded
      ActionMCP::PromptsRegistry.register(self) unless abstract?
    end

    ActiveSupport.on_load(:action_mcp_resource_template) do
      # Register the resource template when it's loaded
      ActionMCP::ResourceTemplatesRegistry.register(self) unless abstract?
    end

    config.to_prepare do
      # Only clear registries if we're in development mode
      if Rails.env.development?
        ActionMCP::ResourceTemplate.registered_templates.clear
        ActionMCP::ToolsRegistry.clear!
        ActionMCP::PromptsRegistry.clear!
      end

      # Eager load MCP components if profile includes "all"
      # This runs after Zeitwerk is fully set up
      ActionMCP.configuration.eager_load_if_needed

      # Register compiled MCP Apps views after registries
      # are (re)built. Runs on each dev reload so rebuilt view bundles/hashes
      # are picked up without restarting the server; runs once at boot in
      # production.
      ActionMCP::Apps::ViewManifest.load! if ActionMCP.configuration.mcp_apps_enabled
    end

    initializer "action_mcp.insert_middleware" do |app|
      endpoint_paths = [ ActionMCP::Engine.endpoint_path_matcher(ActionMCP.configuration.base_path) ].freeze

      config.middleware.use ActionDispatch::HostAuthorization, app.config.hosts if app.config.hosts.present?
      config.middleware.use ActionMCP::Middleware::OriginValidation,
                            endpoint_paths
      config.middleware.use JSONRPC_Rails::Middleware::Validator,
                            endpoint_paths,
                            payload_validator: ActionMCP::ProtocolValidator,
                            batch_policy: :reject,
                            require_json_content_type: true
    end

    # Load MCP profiles during initialization
    initializer "action_mcp.load_profiles" do
      ActionMCP.configuration.load_profiles
    end

    # Initialize MCP logging system
    initializer "action_mcp.initialize_logging" do
      ActionMCP::Logging.initialize_from_config!
    end


    # Configure autoloading for the mcp/tools directory and identifiers
    initializer "action_mcp.autoloading", before: :set_autoload_paths do |app|
      # Ensure ActionMCP base constants exist before Zeitwerk indexes app/mcp
      # This prevents NameError when dependent gems have app/mcp
      # directories with classes inheriting from ActionMCP::Tool, etc.
      require "action_mcp/tool"
      require "action_mcp/prompt"
      require "action_mcp/resource_template"
      require "action_mcp/gateway"

      mcp_path = app.root.join("app/mcp")
      identifiers_path = app.root.join("app/identifiers")

      if mcp_path.exist?
        # First add the parent mcp directory
        app.autoloaders.main.push_dir(mcp_path, namespace: Object)

        # Then collapse the subdirectories to avoid namespacing
        mcp_path.glob("*").select { |f| File.directory?(f) }.each do |dir|
          app.autoloaders.main.collapse(dir)
        end
      end

      # Add identifiers directory for gateway identifiers
      app.autoloaders.main.push_dir(identifiers_path, namespace: Object) if identifiers_path.exist?
    end

    # Initialize the ActionMCP logger.
    initializer "action_mcp.logger" do
      ActionMCP.logger = ::Rails.logger
    end

    # Add metrics instrumentation
    initializer "action_mcp.metrics" do
      ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, start, finish, id, payload|
        if payload[:controller].to_s.start_with?("ActionMCP::")
          # Process action through our log subscriber
          ActionMCP::LogSubscriber.new.process_action(
            ActiveSupport::Notifications::Event.new(name, start, finish, id, payload)
          )
        end
      end

      # Set up default event metrics
      # SQL queries
      ActionMCP::LogSubscriber.subscribe_event "sql.active_record", :db_queries, accumulate: true

      # Query runtime
      ActionMCP::LogSubscriber.subscribe_event "sql.active_record", :sql_runtime,
                                               duration: true, accumulate: true

      # View rendering
      ActionMCP::LogSubscriber.subscribe_event "render_template.action_view", :view_runtime,
                                               duration: true, accumulate: true

      # Cache operations
      ActionMCP::LogSubscriber.subscribe_event "cache_*.*", :cache_operations, accumulate: true
    end
  end
end
