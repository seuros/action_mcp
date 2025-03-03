# frozen_string_literal: true

require "rails"
require "active_support"
require "active_model"
require "action_mcp/version"
require "multi_json"
require "concurrent"
require "action_mcp/engine" if defined?(Rails)
require_relative "action_mcp/integer_array"
require_relative "action_mcp/string_array"
require_relative "action_mcp/logging"
require_relative "action_mcp/configuration"
require_relative "action_mcp/capability"
require_relative "action_mcp/json_rpc"
require_relative "action_mcp/json_rpc_handler"
require_relative "action_mcp/registry_base"

module ActionMCP
  PROTOCOL_VERSION =  "2024-11-05"

  extend ActiveSupport::Autoload

  TRANSPORT_REGISTRY = Concurrent::Map.new

  autoload :RegistryBase
  autoload :Resource
  autoload :ToolsRegistry
  autoload :PromptsRegistry
  autoload :ResourcesBank
  autoload :Tool
  autoload :Prompt
  autoload :Content
  autoload :Transport
  autoload :TransportHandler
  autoload :Client

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

  def transport_registry
    TRANSPORT_REGISTRY
  end

  ActiveModel::Type.register(:string_array, StringArray)
  ActiveModel::Type.register(:integer_array, IntegerArray)
end
