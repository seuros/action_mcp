# frozen_string_literal: true

require "rails"
require "active_model/railtie"

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
      ActiveSupport.on_load(:action_mcp) do
        self.logger = ::Rails.logger
      end
    end
  end
end
