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

  ActiveModel::Type.register(:string_array, StringArray)
  ActiveModel::Type.register(:integer_array, IntegerArray)
end
