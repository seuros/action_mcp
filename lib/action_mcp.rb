# frozen_string_literal: true

require "rails"
require "active_support"
require "active_model"
require "action_mcp/version"
require "multi_json"
require "action_mcp/railtie" if defined?(Rails)
require_relative "action_mcp/integer_array"
require_relative "action_mcp/string_array"

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
  autoload :Transport
  autoload :Content
  autoload :Renderable

  eager_autoload do
    autoload :Configuration
  end

  # Returns the configuration instance.
  #
  # @return [Configuration] the configuration instance
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configures the ActionMCP module.
  #
  # @yield [configuration] the configuration instance
  # @return [void]
  def self.configure
    yield(configuration)
  end

  module_function

  # Returns the tools registry.
  #
  # @return [Hash] the tools registry
  def tools
    ToolsRegistry.tools
  end

  # Returns the prompts registry.
  #
  # @return [Hash] the prompts registry
  def prompts
    PromptsRegistry.prompts
  end

  # Returns the available tools.
  #
  # @return [ActionMCP::RegistryBase::RegistryScope] the available tools
  def available_tools
    ToolsRegistry.available_tools
  end

  # Returns the available prompts.
  #
  # @return [ActionMCP::RegistryBase::RegistryScope] the available prompts
  def available_prompts
    PromptsRegistry.available_prompts
  end

  ActiveModel::Type.register(:string_array, StringArray)
  ActiveModel::Type.register(:integer_array, IntegerArray)
end
