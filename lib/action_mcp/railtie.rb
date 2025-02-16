# frozen_string_literal: true

require "rails"
require "active_model/railtie"

module ActionMCP
  # Railtie for integrating ActionMCP with Rails applications.
  class Railtie < Rails::Railtie # :nodoc:
    # Provide a configuration namespace for ActionMCP
    config.action_mcp = ActiveSupport::OrderedOptions.new

    config.after_initialize do |app|
      options = app.config.action_mcp.to_h.symbolize_keys

      # Override the default configuration if specified in the Rails app.
      ActionMCP.configuration.name = options[:name] if options.key?(:name)
      ActionMCP.configuration.version = options[:version] if options.key?(:version)
      ActionMCP.configuration.logging_enabled = options.fetch(:logging_enabled, true)
    end

    # Initialize the ActionMCP logger.
    initializer "action_mcp.logger" do
      ActiveSupport.on_load(:action_mcp) { self.logger = ::Rails.logger }
    end

    # Clear the ActionMCP registry on each request in development mode.
    #
    # @param app [Rails::Application] The Rails application instance.
    # @return [void]
    initializer "action_mcp.clear_registry" do |app|
      app.config.to_prepare do
        ActionMCP::ToolsRegistry.clear!
        ActionMCP::PromptsRegistry.clear!
      end
    end
  end
end
