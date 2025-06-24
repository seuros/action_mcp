# frozen_string_literal: true

require "rails/generators"

module ActionMCP
  module Generators
    class InstallGenerator < Rails::Generators::Base
      namespace "action_mcp:install"
      source_root File.expand_path("templates", __dir__)

      desc "Install ActionMCP with base classes and configuration"

      def create_application_prompt_file
        template "application_mcp_prompt.rb", File.join("app/mcp/prompts", "application_mcp_prompt.rb")
      end

      def create_application_tool_file
        template "application_mcp_tool.rb", File.join("app/mcp/tools", "application_mcp_tool.rb")
      end

      def create_mcp_resource_template_file
        template "application_mcp_res_template.rb",
                 File.join("app/mcp/resource_templates", "application_mcp_res_template.rb")
      end

      def create_mcp_configuration_file
        template "mcp.yml", File.join("config", "mcp.yml")
      end

      def create_application_gateway_file
        template "application_gateway.rb", File.join("app/mcp", "application_gateway.rb")
      end

      def show_instructions
        say ""
        say "ActionMCP has been installed successfully!"
        say ""
        say "Files created:"
        say "  - app/mcp/prompts/application_mcp_prompt.rb"
        say "  - app/mcp/tools/application_mcp_tool.rb"
        say "  - app/mcp/resource_templates/application_mcp_res_template.rb"
        say "  - app/mcp/application_gateway.rb"
        say "  - config/mcp.yml"
        say ""
        say "Configuration:"
        say "  The mcp.yml file contains authentication, profiles, and adapter settings."
        say "  You can customize authentication methods, OAuth settings, and PubSub adapters."
        say ""
        say "Available adapters:"
        say "  - simple      : In-memory adapter for development"
        say "  - test        : Test adapter for testing environments"
        say "  - solid_cable : Database-backed adapter (requires solid_cable gem)"
        say "  - redis       : Redis-backed adapter (requires redis gem)"
        say ""
        say "Next steps:"
        say "  1. Generate your first tool: rails generate action_mcp:tool MyTool"
        say "  2. Generate your first prompt: rails generate action_mcp:prompt MyPrompt"
        say "  3. Generate your first resource template: rails generate action_mcp:resource_template MyResource"
        say "  4. Start the MCP server: bundle exec rails s -c mcp.ru -p 62770"
        say ""
      end
    end
  end
end
