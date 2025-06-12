# frozen_string_literal: true

require "rails"
require "active_support"
require "active_support/rails"
require "multi_json"
require "concurrent"
require "active_record/railtie"
require "jsonrpc-rails"
require "action_controller/railtie"
require "action_mcp/configuration"
require "action_mcp/log_subscriber"
require "action_mcp/engine"
require "zeitwerk"

# OAuth 2.1 support via Omniauth
require "omniauth"
require "omniauth-oauth2"

lib = File.dirname(__FILE__)

Zeitwerk::Loader.for_gem.tap do |loader|
  loader.ignore(
    "#{lib}/generators",
    "#{lib}/action_mcp/version.rb",
    "#{lib}/action_mcp/gem_version.rb",
    "#{lib}/actionmcp.rb"
  )

  loader.inflector.inflect("action_mcp" => "ActionMCP")
  loader.inflector.inflect("sse_listener" => "SSEListener")
  loader.inflector.inflect("oauth" => "OAuth")
  loader.inflector.inflect("mcp_strategy" => "MCPStrategy")
end.setup

module ActionMCP
  require_relative "action_mcp/version"
  require_relative "action_mcp/client"
  include Logging
  PROTOCOL_VERSION = "2025-03-26"  # Default version
  CURRENT_VERSION = "2025-03-26"   # Current version
  SUPPORTED_VERSIONS = %w[2025-03-26].freeze
  class << self
    # Returns a Rack-compatible application for serving MCP requests
    # This makes ActionMCP.server work similar to ActionCable.server
    # @return [#call] A Rack application that can be used with `run ActionMCP.server`
    def server
      @server ||= begin
        # Initialize the actual server for PubSub.
        # The return value is intentionally discarded as only the side effects are needed.
        Server.server

        # Return the Engine as the Rack application
        # The Engine will handle routing to the UnifiedController
        Engine
      end
    end

    # Returns the configuration instance.
    #
    # @return [Configuration] the configuration instance
    def configuration
      @configuration ||= Configuration.new
    end

    # Configures the ActionMCP module.
    #
    # @yield [configuration] the configuration instance
    # @return [void]
    def configure
      yield(configuration)
    end
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
