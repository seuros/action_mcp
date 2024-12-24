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
  autoload :Tool
  autoload :Prompt
  autoload :JsonRpc

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
