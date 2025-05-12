# frozen_string_literal: true

module ActionMCP
  module Generators
    class ConfigGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates ActionMCP configuration file (config/mcp.yml)"

      def create_mcp_yml
        template "mcp.yml", "config/mcp.yml"
      end

      def show_instructions
        say "ActionMCP configuration file created at config/mcp.yml"
        say "You can customize your PubSub adapters and other settings in this file."
        say ""
        say "Available adapters:"
        say "  - simple   : In-memory adapter for development"
        say "  - test     : Test adapter"
        say "  - solid_cable : Database-backed adapter (requires solid_cable gem)"
        say "  - redis    : Redis-backed adapter (requires redis gem)"
        say ""
        say "Example usage:"
        say "  rails g action_mcp:install  # Main generator"
      end
    end
  end
end
