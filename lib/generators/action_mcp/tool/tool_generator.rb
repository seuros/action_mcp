# frozen_string_literal: true

module ActionMCP
  module Generators
    class ToolGenerator < Rails::Generators::Base
      namespace "action_mcp:tool"
      source_root File.expand_path("templates", __dir__)
      desc "Creates a Tool (in app/mcp/tools) that inherits from ApplicationTool"

      # The generator takes one argument, e.g. "CalculateSum"
      argument :name, type: :string, required: true, banner: "ToolName"

      def create_tool_file
        template "tool.rb.erb", "app/mcp/tools/#{file_name}.rb"
      end

      private

      # Compute the class name ensuring it ends with "Tool"
      def class_name
        "#{name.camelize}#{name.camelize.end_with?('Tool') ? '' : 'Tool'}"
      end

      # Compute the file name ensuring it ends with _tool.rb
      def file_name
        base = name.underscore
        base.end_with?("_tool") ? base : "#{base}_tool"
      end

      # Compute the DSL tool name (a dashed version, without the "Tool" suffix)
      def tool_name
        base = name.to_s
        base = base[0...-4] if base.end_with?("Tool")
        base.underscore.dasherize
      end
    end
  end
end
