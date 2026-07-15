# frozen_string_literal: true

namespace :action_mcp do
  # bin/rails action_mcp:list_tools
  desc "List all tools with their names and descriptions"
  task list_tools: :environment do
    # Ensure Rails eager loads all classes
    Rails.application.eager_load!

    puts "\e[34mACTION MCP TOOLS\e[0m"  # Blue
    puts "\e[34m---------------\e[0m"   # Blue
    tools = ActionMCP::ToolsRegistry.non_abstract.sort_by(&:name)
    if tools.any?
      tools.each do |tool|
        puts "\e[34m#{tool.name}:\e[0m #{tool.description}" # Blue name
      end
    else
      puts "  No tools registered"
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
    prompts = ActionMCP::PromptsRegistry.non_abstract.sort_by(&:name)
    if prompts.any?
      prompts.each do |prompt|
        puts "\e[32m#{prompt.name}:\e[0m #{prompt.description}" # Green name
      end
    else
      puts "  No prompts registered"
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
    resources = ActionMCP::ResourceTemplatesRegistry.non_abstract.sort_by(&:name)
    if resources.any?
      resources.each do |resource|
        puts "\e[33m#{resource.name}:\e[0m #{resource.description} : #{resource.klass.uri_template}" # Yellow name
      end
    else
      puts "  No resources registered"
    end
    puts "\n"
  end

  # bin/rails action_mcp:list_widgets
  desc "List MCP Apps UI widgets and their linked tools"
  task list_widgets: :environment do
    Rails.application.eager_load!

    widgets = ActionMCP::ResourceTemplatesRegistry.non_abstract
      .select { |resource| resource.klass.mime_type == ActionMCP::Apps::MIME_TYPE }
      .sort_by(&:name)
    widget_classes = widgets.map(&:klass)
    tools_by_widget = Hash.new { |linked, widget| linked[widget] = [] }
    missing_resources = Hash.new { |uris, uri| uris[uri] = [] }

    ActionMCP::ToolsRegistry.non_abstract.sort_by(&:name).each do |tool|
      descriptor = tool.klass.to_h(protocol_version: ActionMCP.configuration.protocol_version)
      meta = descriptor[:_meta] || descriptor["_meta"]
      ui = meta && (meta[:ui] || meta["ui"])
      next unless ui.is_a?(Hash)

      resource_uri = ui[:resourceUri] || ui["resourceUri"]
      next unless resource_uri

      visibility = ui[:visibility] || ui["visibility"]
      widget = ActionMCP::ResourceTemplatesRegistry.find_template_for_uri(resource_uri, templates: widget_classes)
      destination = widget ? tools_by_widget[widget] : missing_resources[resource_uri]
      destination << [ tool.name, Array(visibility) ]
    end

    puts "\e[36mACTION MCP UI WIDGETS\e[0m" # Cyan
    puts "\e[36m---------------------\e[0m" # Cyan

    if widgets.any?
      widgets.each do |widget|
        uri = widget.klass.uri_template
        linked_tools = tools_by_widget.fetch(widget.klass, []).map do |tool_name, visibility|
          visibility.any? ? "#{tool_name} [visibility: #{visibility.join(', ')}]" : tool_name
        end

        puts "\e[36m#{widget.name}:\e[0m #{uri}"
        puts "  #{widget.description}" if widget.description.present?
        puts "  Linked tools: #{linked_tools.any? ? linked_tools.join(', ') : 'None'}"
      end
    else
      puts "  No MCP Apps UI widgets registered"
    end

    if missing_resources.any?
      puts "\n\e[31mMISSING UI WIDGET RESOURCES\e[0m" # Red
      puts "\e[31m---------------------------\e[0m" # Red
      missing_resources.sort.each do |uri, linked_tools|
        puts "  #{uri}: #{linked_tools.map(&:first).join(', ')}"
      end
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
      abort "\e[31mProfile '#{profile_name}' not found!\e[0m\n" \
            "Available profiles: #{profiles.keys.join(', ')}"
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

  desc "List all tools, prompts, resources, UI widgets and available profiles"
  task list: %i[list_tools list_prompts list_resources list_widgets list_profiles] do
    # This task lists all registered MCP components and profiles.
  end

  # bin/rails action_mcp:info
  desc "Display the live ActionMCP configuration for the current Rails environment"
  task :info, [ :env ] => :environment do |_t, args|
    requested_env = args[:env]&.to_s
    if requested_env && requested_env != Rails.env
      abort "ActionMCP configuration is initialized when Rails boots. " \
            "Run `RAILS_ENV=#{requested_env} bin/rails action_mcp:info` instead."
    end

    env = Rails.env.to_s
    config = ActionMCP.configuration

    puts "\e[35mActionMCP Configuration (#{env})\e[0m"
    puts "\e[35m#{'=' * (25 + env.length)}\e[0m"

    puts "\n\e[36mBasic Information:\e[0m"
    puts "  Name: #{config.name}"
    puts "  Version: #{config.version}"
    puts "  Protocol Version: #{config.protocol_version}"
    puts "  Active Profile: #{config.active_profile}"

    puts "\n\e[36mTransport:\e[0m"
    puts "  Base Path: #{config.base_path}"
    puts "  Allowed Origins: #{config.allowed_origins.join(', ')}"
    puts "  Pagination Page Size: #{config.pagination_page_size || 'disabled'}"

    puts "\n\e[36mSession Storage:\e[0m"
    puts "  Session Store Type: #{config.session_store_type}"
    puts "  Client Session Store: #{config.client_session_store_type || 'default'}"
    puts "  Server Session Store: #{config.server_session_store_type || 'default'}"

    puts "\n\e[36mThread Pool:\e[0m"
    puts "  Min Threads: #{config.min_threads || 'default'}"
    puts "  Max Threads: #{config.max_threads || 'default'}"
    puts "  Max Queue: #{config.max_queue || 'default'}"

    puts "\n\e[36mAuthentication:\e[0m"
    methods = config.authentication_methods
    puts "  Methods: #{methods.any? ? methods.join(', ') : 'none'}"
    puts "  Allowed Identity Keys: #{config.allowed_identity_keys.join(', ')}"

    puts "\n\e[36mMCP Apps:\e[0m"
    puts "  Enabled: #{config.mcp_apps_enabled}"
    puts "  Views Path: #{config.mcp_apps_views_path}"
    puts "  Widget MIME Type: #{ActionMCP::Apps::MIME_TYPE}"

    puts "\n\e[36mTasks:\e[0m"
    puts "  Enabled: #{config.tasks_enabled}"
    puts "  List Enabled: #{config.tasks_list_enabled}"
    puts "  Cancel Enabled: #{config.tasks_cancel_enabled}"
    puts "  Result Poll Interval: #{config.tasks_result_poll_interval}"

    puts "\n\e[36mLogging:\e[0m"
    puts "  Logging Enabled: #{config.logging_enabled}"
    puts "  Logging Level: #{config.logging_level}"

    puts "\n\e[36mGateway:\e[0m"
    puts "  Gateway Class: #{config.gateway_class || 'not configured'}"

    puts "\n\e[36mEnabled Capabilities:\e[0m"
    capabilities = config.capabilities
    if capabilities.any?
      capabilities.each do |cap_name, cap_config|
        puts "  #{cap_name}: #{cap_config.inspect}"
      end
    else
      puts "  None"
    end

    puts "\n\e[36mAvailable Profiles:\e[0m"
    config.profiles.each_key do |profile_name|
      puts "  - #{profile_name}"
    end

    puts "\n"
  end

  # bin/rails action_mcp:stats
  desc "Display ActionMCP session and database statistics"
  task stats: :environment do
    puts "\e[35mActionMCP Statistics\e[0m"
    puts "\e[35m===================\e[0m"

    database_path = nil

    puts "\n\e[36mDatabase:\e[0m"
    puts "  Rails Environment: #{Rails.env}"
    puts "  Rails Root: #{Rails.root}"
    begin
      connection = ActionMCP::ApplicationRecord.connection
      db_config = ActionMCP::ApplicationRecord.connection_db_config
      puts "  Adapter: #{connection.adapter_name}"
      puts "  Database: #{db_config.database}"

      if connection.adapter_name.downcase.include?("sqlite") && db_config.database != ":memory:"
        configured_path = Pathname.new(db_config.database.to_s)
        database_path = configured_path.absolute? ? configured_path : Rails.root.join(configured_path)
        puts "  Database Path: #{database_path}"
        puts "  Database Exists?: #{database_path.file?}"
      end
    rescue StandardError => e
      puts "  Could not inspect database connection: #{e.message}"
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

    # Storage Information
    puts "\n\e[36mStorage Information:\e[0m"
    puts "  Session Store Type: #{ActionMCP.configuration.session_store_type}"

    begin
      connection = ActionMCP::ApplicationRecord.connection
      puts "  Database Adapter: #{connection.adapter_name}"
      if database_path&.file?
        size_mb = (database_path.size / 1024.0 / 1024.0).round(2)
        puts "  Database Size: #{size_mb} MB"
      end
    rescue StandardError => e
      puts "  Could not determine database size: #{e.message}"
    end

    puts "\n"
  end
end
