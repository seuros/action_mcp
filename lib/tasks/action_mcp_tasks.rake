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

  # bin/rails action_mcp:list_profiles
  desc "List all available profiles"
  task list_profiles: :environment do
    # Ensure Rails eager loads all classes
    Rails.application.eager_load!

    puts "\e[35mACTION MCP PROFILES\e[0m"  # Purple
    puts "\e[35m-------------------\e[0m"   # Purple

    profiles = ActionMCP.configuration.profiles

    if profiles.any?
      profiles.each_key do |profile_name|
        puts "\e[35m#{profile_name}\e[0m"
      end
    else
      puts "  No profiles configured"
    end

    puts "\n"
  end

  # bin/rails action_mcp:show_profile[profile_name]
  desc "Show configuration for a specific profile"
  task :show_profile, [ :profile_name ] => :environment do |_t, args|
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

      puts "\e[35mPROFILE: #{profile_name.to_s.upcase}\e[0m" # Purple
      puts "\e[35m#{'-' * (profile_name.to_s.length + 9)}\e[0m"

      # Show options
      if profile_config[:options]
        puts "\n\e[36mOptions:\e[0m" # Cyan
        profile_config[:options].each do |key, value|
          puts "  #{key}: #{value}"
        end
      end

      # Show Tools
      puts "\n\e[34mIncluded Tools:\e[0m" # Blue
      if ActionMCP.configuration.filtered_tools.any?
        ActionMCP.configuration.filtered_tools.each do |tool|
          puts "  \e[34m#{tool.name}:\e[0m #{tool.description}"
        end
      else
        puts "  None"
      end

      # Show Prompts
      puts "\n\e[32mIncluded Prompts:\e[0m" # Green
      if ActionMCP.configuration.filtered_prompts.any?
        ActionMCP.configuration.filtered_prompts.each do |prompt|
          puts "  \e[32m#{prompt.name}:\e[0m #{prompt.description}"
        end
      else
        puts "  None"
      end

      # Show Resources
      puts "\n\e[33mIncluded Resources:\e[0m" # Yellow
      if ActionMCP.configuration.filtered_resources.any?
        ActionMCP.configuration.filtered_resources.each do |resource|
          puts "  \e[33m#{resource.name}:\e[0m #{resource.description}"
        end
      else
        puts "  None"
      end

      # Show Capabilities
      puts "\n\e[36mActive Capabilities:\e[0m" # Cyan
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

  # bin/rails action_mcp:info
  # bin/rails action_mcp:info[test]
  desc "Display ActionMCP configuration for current or specified environment"
  task :info, [ :env ] => :environment do |_t, args|
    env = args[:env] || Rails.env

    # Load configuration for the specified environment
    original_env = Rails.env
    Rails.env = env.to_s

    # Reload configuration to get the environment-specific settings
    config = ActionMCP::Configuration.new
    config.load_profiles

    puts "\e[35mActionMCP Configuration (#{env})\e[0m"
    puts "\e[35m#{'=' * (25 + env.length)}\e[0m"

    # Basic Information
    puts "\n\e[36mBasic Information:\e[0m"
    puts "  Name: #{config.name}"
    puts "  Version: #{config.version}"
    puts "  Protocol Version: #{config.protocol_version}"
    puts "  Active Profile: #{config.active_profile}"

    # Session Storage
    puts "\n\e[36mSession Storage:\e[0m"
    puts "  Session Store Type: #{config.session_store_type}"
    puts "  Client Session Store: #{config.client_session_store_type || 'default'}"
    puts "  Server Session Store: #{config.server_session_store_type || 'default'}"

    # Transport Configuration
    puts "\n\e[36mTransport Configuration:\e[0m"
    puts "  SSE Heartbeat Interval: #{config.sse_heartbeat_interval}s"
    puts "  Post Response Preference: #{config.post_response_preference}"
    puts "  SSE Event Retention Period: #{config.sse_event_retention_period}"
    puts "  Max Stored SSE Events: #{config.max_stored_sse_events}"

    # Pub/Sub Adapter
    puts "\n\e[36mPub/Sub Adapter:\e[0m"
    puts "  Adapter: #{config.adapter || 'not configured'}"
    if config.adapter
      puts "  Polling Interval: #{config.polling_interval}" if config.polling_interval
      puts "  Min Threads: #{config.min_threads}" if config.min_threads
      puts "  Max Threads: #{config.max_threads}" if config.max_threads
      puts "  Max Queue: #{config.max_queue}" if config.max_queue
    end

    # Authentication
    puts "\n\e[36mAuthentication:\e[0m"
    puts "  Methods: #{config.authentication_methods.join(', ')}"
    if config.oauth_config&.any?
      puts "  OAuth Provider: #{config.oauth_config['provider']}"
      puts "  OAuth Scopes: #{config.oauth_config['scopes_supported']&.join(', ')}"
    end

    # Logging
    puts "\n\e[36mLogging:\e[0m"
    puts "  Logging Enabled: #{config.logging_enabled}"
    puts "  Logging Level: #{config.logging_level}"

    # Gateway
    puts "\n\e[36mGateway:\e[0m"
    puts "  Gateway Class: #{config.gateway_class}"

    # Capabilities
    puts "\n\e[36mEnabled Capabilities:\e[0m"
    capabilities = config.capabilities
    if capabilities.any?
      capabilities.each do |cap_name, cap_config|
        puts "  #{cap_name}: #{cap_config.inspect}"
      end
    else
      puts "  None"
    end

    # Available Profiles
    puts "\n\e[36mAvailable Profiles:\e[0m"
    config.profiles.each_key do |profile_name|
      puts "  - #{profile_name}"
    end

    # Restore original environment
    Rails.env = original_env

    puts "\n"
  end

  # bin/rails action_mcp:stats
  desc "Display ActionMCP session and database statistics"
  task stats: :environment do
    puts "\e[35mActionMCP Statistics\e[0m"
    puts "\e[35m===================\e[0m"

    # Debug database connection
    puts "\n\e[36mDatabase Debug:\e[0m"
    puts "  Rails Environment: #{Rails.env}"
    puts "  Rails Root: #{Rails.root}"
    puts "  Database Config: #{ActionMCP::ApplicationRecord.connection_db_config.configuration_hash.inspect}"
    if ActionMCP::ApplicationRecord.connection.adapter_name.downcase.include?("sqlite")
      db_path = ActionMCP::ApplicationRecord.connection_db_config.database
      puts "  Database Path: #{db_path}"
      puts "  Database Exists?: #{File.exist?(db_path)}" if db_path
    end

    # Session Statistics
    puts "\n\e[36mSession Statistics:\e[0m"

    begin
      total_sessions = ActionMCP::Session.count
      puts "  Total Sessions: #{total_sessions}"

      if total_sessions.positive?
        # Sessions by status
        sessions_by_status = ActionMCP::Session.group(:status).count
        puts "  Sessions by Status:"
        sessions_by_status.each do |status, count|
          puts "    #{status}: #{count}"
        end

        # Sessions by protocol version
        sessions_by_protocol = ActionMCP::Session.group(:protocol_version).count
        puts "  Sessions by Protocol Version:"
        sessions_by_protocol.each do |version, count|
          puts "    #{version}: #{count}"
        end

        # Active sessions (initialized and not ended)
        active_sessions = ActionMCP::Session.where(status: "initialized", ended_at: nil).count
        puts "  Active Sessions: #{active_sessions}"

        # Recent activity
        recent_sessions = ActionMCP::Session.where("created_at > ?", 1.hour.ago).count
        puts "  Sessions Created (Last Hour): #{recent_sessions}"

        # Session with most messages
        if ActionMCP::Session.maximum(:messages_count)
          busiest_session = ActionMCP::Session.order(messages_count: :desc).first
          puts "  Most Active Session: #{busiest_session.id} (#{busiest_session.messages_count} messages)"
        end

        # Average messages per session
        avg_messages = ActionMCP::Session.average(:messages_count).to_f.round(2)
        puts "  Average Messages per Session: #{avg_messages}"
      end
    rescue StandardError => e
      puts "  Error accessing session data: #{e.message}"
      puts "  (Session store might be using volatile storage)"
    end

    # Message Statistics (if messages table exists)
    puts "\n\e[36mMessage Statistics:\e[0m"

    begin
      if ActionMCP::ApplicationRecord.connection.table_exists?("action_mcp_session_messages")
        total_messages = ActionMCP::Session::Message.count
        puts "  Total Messages: #{total_messages}"

        if total_messages.positive?
          # Messages by direction
          messages_by_direction = ActionMCP::Session::Message.group(:direction).count
          puts "  Messages by Direction:"
          messages_by_direction.each do |direction, count|
            puts "    #{direction}: #{count}"
          end

          # Messages by type
          messages_by_type = ActionMCP::Session::Message.group(:message_type).count.sort_by do |_type, count|
            -count
          end.first(10)
          puts "  Top Message Types:"
          messages_by_type.each do |type, count|
            puts "    #{type}: #{count}"
          end

          # Recent messages
          recent_messages = ActionMCP::Session::Message.where("created_at > ?", 1.hour.ago).count
          puts "  Messages (Last Hour): #{recent_messages}"
        end
      else
        puts "  Message table not found"
      end
    rescue StandardError => e
      puts "  Error accessing message data: #{e.message}"
    end

    # SSE Event Statistics (if table exists)
    puts "\n\e[36mSSE Event Statistics:\e[0m"

    begin
      if ActionMCP::ApplicationRecord.connection.table_exists?("action_mcp_sse_events")
        total_events = ActionMCP::Session::SSEEvent.count
        puts "  Total SSE Events: #{total_events}"

        if total_events.positive?
          # Recent events
          recent_events = ActionMCP::Session::SSEEvent.where("created_at > ?", 1.hour.ago).count
          puts "  SSE Events (Last Hour): #{recent_events}"

          # Events by session
          events_by_session = ActionMCP::Session::SSEEvent.joins(:session)
                                                          .group("action_mcp_sessions.id")
                                                          .count
                                                          .sort_by { |_session_id, count| -count }
                                                          .first(5)
          puts "  Top Sessions by SSE Events:"
          events_by_session.each do |session_id, count|
            puts "    #{session_id}: #{count} events"
          end
        end
      else
        puts "  SSE Events table not found"
      end
    rescue StandardError => e
      puts "  Error accessing SSE event data: #{e.message}"
    end

    # Storage Information
    puts "\n\e[36mStorage Information:\e[0m"
    puts "  Session Store Type: #{ActionMCP.configuration.session_store_type}"
    puts "  Database Adapter: #{ActionMCP::ApplicationRecord.connection.adapter_name}"

    # Database size (if SQLite)
    begin
      if ActionMCP::ApplicationRecord.connection.adapter_name.downcase.include?("sqlite")
        db_config = Rails.application.config.database_configuration[Rails.env]
        if db_config && db_config["database"]
          db_file = db_config["database"]
          if File.exist?(db_file)
            size_mb = (File.size(db_file) / 1024.0 / 1024.0).round(2)
            puts "  Database Size: #{size_mb} MB"
          end
        end
      end
    rescue StandardError => e
      puts "  Could not determine database size: #{e.message}"
    end

    puts "\n"
  end
end
