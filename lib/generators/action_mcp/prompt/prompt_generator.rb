# frozen_string_literal: true

module ActionMCP
  module Generators
    class PromptGenerator < Rails::Generators::Base
      namespace "action_mcp:prompt"
      source_root File.expand_path("templates", __dir__)
      desc "Creates a Prompt (in app/prompts) that inherits from ApplicationPrompt"

      # The generator takes one argument, e.g. "AnalyzeCode"
      argument :name, type: :string, required: true, banner: "PromptName"

      def create_prompt_file
        template "prompt.rb.erb", "app/prompts/#{file_name}.rb"
      end

      private

      # Build the class name, ensuring it ends with "Prompt"
      def class_name
        "#{name.camelize}#{name.camelize.end_with?('Prompt') ? '' : 'Prompt'}"
      end

      # Build the file name (underscore and ensure it ends with _prompt)
      def file_name
        base = name.underscore
        base.end_with?("_prompt") ? base : "#{base}_prompt"
      end

      # Build the DSL prompt name (a dashed version, without the "Prompt" suffix)
      def prompt_name
        base = name.to_s
        base = base[0...-6] if base.end_with?("Prompt")
        base.underscore.dasherize
      end
    end
  end
end
