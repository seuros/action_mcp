# frozen_string_literal: true

module ActionMCP
  module Generators
    class ToolGenerator < Rails::Generators::Base
      namespace "action_mcp:tool"
      source_root File.expand_path("templates", __dir__)
      desc "Creates a Tool (in app/mcp/tools) that inherits from ApplicationMCPTool"

      argument :name, type: :string, required: true, banner: "ToolName"

      class_option :description, type: :string, default: "Describe what this tool does"
      class_option :read_only, type: :boolean, default: false
      class_option :destructive, type: :boolean, default: false
      class_option :category, type: :string, default: nil
      class_option :properties, type: :array, default: [], banner: "name:type:description:required"

      def create_tool_file
        template "tool.rb.erb", "app/mcp/tools/#{file_name}.rb"
      end

      private

      def class_name
        "#{name.camelize}#{name.camelize.end_with?('Tool') ? '' : 'Tool'}"
      end

      def file_name
        base = name.underscore
        base.end_with?("_tool") ? base : "#{base}_tool"
      end

      def tool_name
        base = name.to_s
        base = base.end_with?("Tool") ? base[0..-5] : base
        base.underscore.dasherize
      end

      def description
        options[:description]
      end

      def annotations
        ann = {}
        ann[:read_only] = true if options[:read_only]
        ann[:destructive] = true if options[:destructive]
        ann[:category] = options[:category] if options[:category]
        ann
      end

      def properties
        options[:properties].map do |prop|
          parts = prop.split(":")
          {
            name: parts[0],
            type: parts[1] || "string",
            description: parts[2] || "No description provided",
            required: parts[3] == "true"
          }
        end
      end
    end
  end
end
