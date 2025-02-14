module ActionMCP
  module Generators
    class InstallGenerator < Rails::Generators::Base
      namespace "action_mcp:install"
      source_root File.expand_path("templates", __dir__)
      desc "Installs both ApplicationPrompt and ApplicationTool"
      def create_application_prompt
        template "application_prompt.rb", "app/prompts/application_prompt.rb"
      end

      def create_application_tool
        template "application_tool.rb", "app/tools/application_tool.rb"
      end
    end
  end
end
