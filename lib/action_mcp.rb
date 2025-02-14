# frozen_string_literal: true

require "rails"
require "active_support"
require "active_model"
require "action_mcp/version"
require "action_mcp/railtie" if defined?(Rails)

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "MCP"
end
module ActionMCP
  extend ActiveSupport::Autoload

  autoload :RegistryBase
  autoload :Resource
  autoload :ToolsRegistry
  autoload :PromptsRegistry
  autoload :ResourcesBank
  autoload :Tool
  autoload :Prompt
  autoload :JsonRpc
  eager_autoload do
    autoload :Configuration
  end

  # Accessor for the configuration instance.
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  module_function

  def tools
    ToolsRegistry.tools
  end

  def prompts
    PromptsRegistry.prompts
  end

  def available_tools
    ToolsRegistry.available_tools
  end

  def available_prompts
    PromptsRegistry.available_prompts
  end
end
