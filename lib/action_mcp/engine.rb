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
      inflect.acronym "OAuth"
    end

    # Provide a configuration namespace for ActionMCP
    config.action_mcp = ActionMCP.configuration

    config.to_prepare do
      ActionMCP::ResourceTemplate.registered_templates.clear
      ActionMCP::ToolsRegistry.clear!
      ActionMCP::PromptsRegistry.clear!
    end

    config.middleware.use JSONRPC_Rails::Middleware::Validator, [ "/" ]

    # Load MCP profiles during initialization
    initializer "action_mcp.load_profiles" do
      ActionMCP.configuration.load_profiles
    end

    # Add OAuth middleware if OAuth is configured
    initializer "action_mcp.oauth_middleware", after: "action_mcp.load_profiles" do
      if ActionMCP.configuration.authentication_methods&.include?("oauth")
        config.middleware.use ActionMCP::OAuth::Middleware
      end
    end

    # Configure autoloading for the mcp/tools directory
    initializer "action_mcp.autoloading", before: :set_autoload_paths do |app|
      mcp_path = app.root.join("app/mcp")

      if mcp_path.exist?
        # First add the parent mcp directory
        app.autoloaders.main.push_dir(mcp_path, namespace: Object)

        # Then collapse the subdirectories to avoid namespacing
        mcp_path.glob("*").select { |f| File.directory?(f) }.each do |dir|
          app.autoloaders.main.collapse(dir)
        end
      end
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
