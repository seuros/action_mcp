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

    config.to_prepare do
      ActionMCP::ResourceTemplate.registered_templates.clear
    end

    config.middleware.use JSONRPC_Rails::Middleware::Validator, [ ActionMCP.configuration.mcp_endpoint_path ]

    # Load MCP profiles during initialization
    initializer "action_mcp.load_profiles" do
      ActionMCP.configuration.load_profiles
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
  end
end
