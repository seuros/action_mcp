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

    puts "\e[32mACTION MCP PROMPTS\e[0m"  # Green
    puts "\e[32m-----------------\e[0m"   # Green
    ActionMCP::Prompt.descendants.each do |prompt|
      next if prompt.abstract?

      puts "\e[32m#{prompt.capability_name}:\e[0m #{prompt.description}" # Green name
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

  # bin/rails action_mcp:show_profile[profile_name]
  desc "Show configuration for a specific profile"
  task :show_profile, [ :profile_name ] => :environment do |t, args|
    # Ensure Rails eager loads all classes
    Rails.application.eager_load!

    profile_name = (args[:profile_name] || "primary").to_sym
    profiles = ActionMCP.configuration.profiles

    unless profiles.key?(profile_name)
      puts "\e[31mProfile '#{profile_name}' not found!\e[0m"
      puts "Available profiles: #{profiles.keys.join(', ')}"
      next
    end

    # Temporarily activate this profile to show what would be included
    ActionMCP.with_profile(profile_name) do
      profile_config = profiles[profile_name]

      puts "\e[35mPROFILE: #{profile_name.to_s.upcase}\e[0m"  # Purple
      puts "\e[35m#{'-' * (profile_name.to_s.length + 9)}\e[0m"

      # Show options
      if profile_config[:options]
        puts "\n\e[36mOptions:\e[0m"  # Cyan
        profile_config[:options].each do |key, value|
          puts "  #{key}: #{value}"
        end
      end

      # Show Tools
      puts "\n\e[34mIncluded Tools:\e[0m"  # Blue
      if ActionMCP.configuration.filtered_tools.any?
        ActionMCP.configuration.filtered_tools.each do |tool|
          puts "  \e[34m#{tool.name}:\e[0m #{tool.description}"
        end
      else
        puts "  None"
      end

      # Show Prompts
      puts "\n\e[32mIncluded Prompts:\e[0m"  # Green
      if ActionMCP.configuration.filtered_prompts.any?
        ActionMCP.configuration.filtered_prompts.each do |prompt|
          puts "  \e[32m#{prompt.name}:\e[0m #{prompt.description}"
        end
      else
        puts "  None"
      end

      # Show Resources
      puts "\n\e[33mIncluded Resources:\e[0m"  # Yellow
      if ActionMCP.configuration.filtered_resources.any?
        ActionMCP.configuration.filtered_resources.each do |resource|
          puts "  \e[33m#{resource.name}:\e[0m #{resource.description}"
        end
      else
        puts "  None"
      end

      # Show Capabilities
      puts "\n\e[36mActive Capabilities:\e[0m"  # Cyan
      capabilities = ActionMCP.configuration.capabilities
      capabilities.each do |cap_name, cap_config|
        puts "  #{cap_name}: #{cap_config.inspect}"
      end
    end

    puts "\n"
  end

  desc "List all tools, prompts, resources and available profiles"
  task list: %i[list_tools list_prompts list_resources list_profiles] do
    # This task lists all tools, prompts, resources and profiles
  end
end
