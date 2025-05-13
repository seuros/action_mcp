# frozen_string_literal: true

require_relative "server/simple_pub_sub"
require_relative "server/configuration"

# Conditionally load adapters based on available gems
begin
  require "solid_cable/pubsub"
  require_relative "server/solid_cable_adapter"
rescue LoadError
  # SolidCable not available
end

module ActionMCP
  # Module for server-related functionality.
  module Server
    module_function

    def server
      @server ||= ServerBase.new
    end

    # Shut down the server and clean up resources
    def shutdown
      return unless @server

      @server.shutdown
      @server = nil
    end

    # Available pubsub adapter types
    ADAPTERS = {
      "test" => "SimplePubSub",
      "simple" => "SimplePubSub",
      "solid_cable" => "SolidCableAdapter" # Will use mock version in tests
    }.compact.freeze

    # Custom server base class for PubSub functionality
    class ServerBase
      def initialize(config_path = nil)
        @configuration = Configuration.new(config_path)
      end

      def pubsub
        @pubsub ||= create_pubsub
      end

      # Allow manual override of the configuration
      # @param config_path [String] Path to a cable.yml configuration file
      def configure(config_path)
        shutdown_pubsub if @pubsub
        @configuration = Configuration.new(config_path)
        @pubsub = nil # Reset pubsub so it will be recreated with new config
      end

      # Gracefully shut down the server and its resources
      def shutdown
        shutdown_pubsub
      end

      private

      # Shut down the pubsub adapter gracefully
      def shutdown_pubsub
        return unless @pubsub.respond_to?(:shutdown)

        begin
          @pubsub.shutdown
        rescue StandardError => e
          message = "Error shutting down pubsub adapter: #{e.message}"
          Rails.logger.error(message) if defined?(Rails) && Rails.respond_to?(:logger)
        ensure
          @pubsub = nil
        end
      end

      def create_pubsub
        adapter_name = @configuration.adapter_name
        adapter_options = @configuration.adapter_options

        # Default to simple if adapter not found
        adapter_class_name = ADAPTERS[adapter_name] || "SimplePubSub"

        begin
          # Create an instance of the adapter class with the configuration options
          adapter_class = ActionMCP::Server.const_get(adapter_class_name)
          adapter_class.new(adapter_options)
        rescue NameError, LoadError => e
          message = "Error creating adapter #{adapter_name}: #{e.message}"
          Rails.logger.error(message) if defined?(Rails) && Rails.respond_to?(:logger)
          SimplePubSub.new # Fallback to simple pubsub
        end
      end
    end
  end
end
