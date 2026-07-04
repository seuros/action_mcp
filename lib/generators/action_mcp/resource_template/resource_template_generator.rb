# frozen_string_literal: true

require "rails/generators"

module ActionMCP
  module Generators
    class ResourceTemplateGenerator < Rails::Generators::NamedBase
      namespace "action_mcp:resource_template"
      source_root File.expand_path("templates", __dir__)
      desc "Creates a ResourceTemplate (in app/mcp/resource_templates) that inherits from ApplicationMCPResTemplate"

      argument :name, type: :string, required: true, banner: "ResourceTemplateName"

      class_option :ui, type: :boolean, default: false,
                        desc: "Generate an MCP Apps UI template (ui:// URI, :mcp_app mime type, render_ui)"

      def create_resource_template_file
        source = options[:ui] ? "resource_template_ui.rb.erb" : "resource_template.rb.erb"
        template source, "app/mcp/resource_templates/#{file_name}.rb"
      end

      private

      def class_name
        "#{name.camelize}#{name.camelize.end_with?('Template') ? '' : 'Template'}"
      end

      def file_name
        base = name.underscore
        base.end_with?("_template") ? base : "#{base}_template"
      end

      # Name without the Template suffix, for view paths and ui:// URIs.
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
