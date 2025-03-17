# frozen_string_literal: true

require "rails/generators"

module ActionMcp
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

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
    end
  end
end
