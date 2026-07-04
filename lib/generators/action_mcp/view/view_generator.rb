# frozen_string_literal: true

require "rails/generators"

module ActionMCP
  module Generators
    class ViewGenerator < Rails::Generators::NamedBase
      namespace "action_mcp:view"
      source_root File.expand_path("templates", __dir__)
      desc "Creates an MCP Apps UI view: a ui:// ResourceTemplate (in app/mcp/resource_templates) " \
           "paired with an ERB view (in app/views/mcp/ui)"

      argument :name, type: :string, required: true, banner: "ViewName"

      def create_resource_template_file
        template "resource_template.rb.erb", "app/mcp/resource_templates/#{file_name}.rb"
      end

      def create_view_file
        template "view.html.erb", "app/views/mcp/ui/#{view_name}.html.erb"
      end

      def show_instructions
        say <<~INSTRUCTIONS

          MCP Apps view created. Next steps:
            1. Enable MCP Apps in config/mcp.yml: mcp_apps_enabled: true
            2. Link a tool to this view: renders_ui "ui://views/#{uri_name}"
            3. Edit app/views/mcp/ui/#{view_name}.html.erb
        INSTRUCTIONS
      end

      private

      def class_name
        "#{base_name.camelize}Template"
      end

      def file_name
        "#{view_name}_template"
      end

      # Name without a trailing Template suffix, used for the view path and URI.
      def base_name
        name.camelize.delete_suffix("Template")
      end

      def view_name
        base_name.underscore
      end

      def uri_name
        view_name.dasherize
      end
    end
  end
end
