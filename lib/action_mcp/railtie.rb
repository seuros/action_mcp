require "rails"
require "active_model/railtie"

module ActionMCP
  class Railtie < Rails::Railtie # :nodoc:
    # TODO: fix this to be a proper railtie if you going to to opensource it
    initializer "action_mcp.clear_registry" do |app|
      app.config.to_prepare do
        ActionMCP::ToolsRegistry.clear!
        ActionMCP::PromptsRegistry.clear!
      end
    end
  end
end
