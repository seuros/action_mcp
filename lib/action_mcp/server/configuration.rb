# frozen_string_literal: true

require "yaml"
require "erb"

module ActionMCP
  module Server
    # Configuration loader for ActionMCP server
    class Configuration
      attr_reader :config

      def initialize(config_path = nil)
        @config_path = config_path || default_config_path
        @config = load_config
      end

      # Get the configuration for the current environment
      def for_env(env = nil)
        environment = env || (defined?(Rails) ? Rails.env : "development")
        config[environment] || config["development"] || {}
      end

      # Get the adapter name for the current environment
      def adapter_name(env = nil)
        env_config = for_env(env)
        env_config["adapter"]
      end

      # Get the adapter options for the current environment
      def adapter_options(env = nil)
        env_config = for_env(env)
        env_config.except("adapter")
      end

      private

      def load_config
        return {} unless File.exist?(@config_path.to_s)

        yaml = ERB.new(File.read(@config_path)).result
        YAML.safe_load(yaml, aliases: true) || {}
      rescue StandardError => e
        if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger.error("Error loading ActionMCP config: #{e.message}")
        end
        {}
      end

      def default_config_path
        return Rails.root.join("config", "mcp.yml") if defined?(Rails) && Rails.respond_to?(:root)

        # Fallback to looking for a mcp.yml in the current directory or parent directories
        path = Dir.pwd
        while path != "/"
          config_path = File.join(path, "config", "mcp.yml")
          return config_path if File.exist?(config_path)

          path = File.dirname(path)
        end

        # Default to an empty config if no mcp.yml found
        nil
      end
    end
  end
end
