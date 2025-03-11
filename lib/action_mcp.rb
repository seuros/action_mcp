# frozen_string_literal: true

require "rails"
require "active_support"
require "active_support/rails"
require "multi_json"
require "concurrent"
require "active_record/railtie"
require "action_controller/railtie"
require "action_cable/engine"
require "action_mcp/engine"
require "zeitwerk"

lib = File.dirname(__FILE__)

Zeitwerk::Loader.for_gem.tap do |loader|
  loader.ignore(
    "#{lib}/generators",
    "#{lib}/action_mcp/version.rb",
    "#{lib}/action_mcp/gem_version.rb",
    "#{lib}/actionmcp.rb"
  )

  loader.inflector.inflect("action_mcp" => "ActionMCP")
  loader.inflector.inflect("sse_client" => "SSEClient")
  loader.inflector.inflect("sse_server" => "SSEServer")
end.setup

module ActionMCP
  require_relative "action_mcp/version"
  require_relative "action_mcp/configuration"
  PROTOCOL_VERSION =  "2024-11-05"

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
