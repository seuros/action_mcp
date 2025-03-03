# frozen_string_literal: true

require "rails"
require "active_model/railtie"

module ActionMCP
  # Engine for integrating ActionMCP with Rails applications.
  class Engine < ::Rails::Engine
    isolate_namespace ActionMCP
    config.eager_load_namespaces << ::ActionMCP

    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym "SSE"
      inflect.acronym "MCP"
    end
    # Provide a configuration namespace for ActionMCP
    config.action_mcp = ActiveSupport::OrderedOptions.new

    initializer "action_mcp.configure" do |app|
      options = app.config.action_mcp.to_h.symbolize_keys

      # Override the default configuration if specified in the Rails app.
      ActionMCP.configuration.name            = options[:name] if options.key?(:name)
      ActionMCP.configuration.version         = options[:version] if options.key?(:version)
      ActionMCP.configuration.logging_enabled = options.fetch(:logging_enabled, true)
    end

    # Initialize the ActionMCP logger.
    initializer "action_mcp.logger" do
      ActiveSupport.on_load(:action_mcp) do
        self.logger = ::Rails.logger
      end
    end
  end
end
