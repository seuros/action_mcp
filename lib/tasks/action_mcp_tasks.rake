# frozen_string_literal: true

namespace :action_mcp do
  # bin/rails action_mcp:list_tools
  desc "List all tools with their names and descriptions"
  task list_tools: :environment do
    # Ensure Rails eager loads all classes
    Rails.application.eager_load!

    puts "\e[34mACTION MCP TOOLS\e[0m"  # Blue
    puts "\e[34m---------------\e[0m"   # Blue
    ActionMCP::Tool.descendants.each do |tool|
      next if tool.abstract?

      puts "\e[34m#{tool.capability_name}:\e[0m #{tool.description}" # Blue name
    end
    puts "\n"
  end

  # bin/rails action_mcp:list_prompts
  desc "List all prompts with their names and descriptions"
  task list_prompts: :environment do
    # Ensure Rails eager loads all classes
    Rails.application.eager_load!

    puts "\e[32mACTION MCP PROMPTS\e[0m"  # Red
    puts "\e[32m-----------------\e[0m"   # Red
    ActionMCP::Prompt.descendants.each do |prompt|
      next if prompt.abstract?

      puts "\e[32m#{prompt.capability_name}:\e[0m #{prompt.description}" # Red name
    end
    puts "\n"
  end

  # bin/rails action_mcp:list_resources
  desc "List all resources with their names and descriptions"
  task list_resources: :environment do
    # Ensure Rails eager loads all classes
    Rails.application.eager_load!

    puts "\e[33mACTION MCP RESOURCES\e[0m" # Yellow
    puts "\e[33m--------------------\e[0m" # Yellow
    ActionMCP::ResourceTemplate.descendants.each do |resource|
      next if resource.abstract?

      puts "\e[33m#{resource.capability_name}:\e[0m #{resource.description} : #{resource.uri_template}" # Yellow name
    end
    puts "\n"
  end

  desc "List all tools and prompts with their names and descriptions"
  task list: %i[list_tools list_prompts list_resources] do
    # This task lists all tools, prompts, and resources
  end
end
