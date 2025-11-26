# frozen_string_literal: true

require "rails"
require "active_model/railtie"
require "jsonrpc-rails"

module ActionMCP
  # Engine for integrating ActionMCP with Rails applications.
  class Engine < ::Rails::Engine
    isolate_namespace ActionMCP

    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym "SSE"
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
    end

    config.middleware.use JSONRPC_Rails::Middleware::Validator, [ "/" ]

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
