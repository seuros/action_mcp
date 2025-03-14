namespace :action_mcp do
  desc "List all tools with their names and descriptions"
  task list_tools: :environment do
    # Ensure Rails eager loads all classes
    Rails.application.eager_load!

    puts "\e[34mACTION MCP TOOLS\e[0m"  # Blue
    puts "\e[34m---------------\e[0m"   # Blue
    ActionMCP::Tool.descendants.each do |tool|
      puts "\e[34m#{tool.capability_name}:\e[0m #{tool.description}"  # Blue name
    end
  end

  desc "List all prompts with their names and descriptions"
  task list_prompts: :environment do
    # Ensure Rails eager loads all classes
    Rails.application.eager_load!

    puts "\e[32mACTION MCP PROMPTS\e[0m"  # Red
    puts "\e[32m-----------------\e[0m"   # Red
    ActionMCP::Prompt.descendants.each do |prompt|
      puts "\e[32m#{prompt.capability_name}:\e[0m #{prompt.description}"  # Red name
    end
  end

  desc "List all tools and prompts with their names and descriptions"
  task list: [ :list_tools, :list_prompts ] do
    # This task lists all tools and prompts
  end
end
