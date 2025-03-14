require "rails/generators"

module ActionMcp
  module Generators
    class ResourceTemplateGenerator < Rails::Generators::NamedBase
      namespace "action_mcp:resource_template"
      source_root File.expand_path("templates", __dir__)
      desc "Creates a ResourceTemplate (in app/mcp/resource_templates) that inherits from MCPResourceTemplate"

      argument :name, type: :string, required: true, banner: "ResourceTemplateName"

      def create_resource_template_file
        template "resource_template.rb.erb", "app/mcp/resource_templates/#{file_name}.rb"
      end

      private

      def class_name
        "#{name.camelize}#{name.camelize.end_with?('Template') ? '' : 'Template'}"
      end

      def file_name
        base = name.underscore
        base.end_with?("_template") ? base : "#{base}_template"
      end
    end
  end
end
