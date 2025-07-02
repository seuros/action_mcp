# frozen_string_literal: true

module ActionMCP
  module Server
    # Memory-based session object that mimics ActiveRecord Session
    class MemorySession
      attr_accessor :id, :status, :initialized, :role, :messages_count,
                    :sse_event_counter, :protocol_version, :client_info,
                    :client_capabilities, :server_info, :server_capabilities,
                    :tool_registry, :prompt_registry, :resource_registry,
                    :created_at, :updated_at, :ended_at, :last_event_id,
                    :session_data

      def initialize(attributes = {}, store = nil)
        @store = store
        @messages = Concurrent::Array.new
        @subscriptions = Concurrent::Array.new
        @resources = Concurrent::Array.new
        @sse_events = Concurrent::Array.new
        @sse_counter = Concurrent::AtomicFixnum.new(0)
        @message_counter = Concurrent::AtomicFixnum.new(0)
        @new_record = true

        attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
      end

      # Mimic ActiveRecord interface
      def new_record?
        @new_record
      end

      def persisted?
        !@new_record
      end

      def save
        self.updated_at = Time.current
        @store.save_session(self) if @store
        @new_record = false
        true
      end

      def save!
        save
      end

      def update(attributes)
        attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
        save
      end

      def update!(attributes)
        update(attributes)
      end

      def destroy
        @store.delete_session(id) if @store
      end

      def reload
        self
      end

      def initialized?
        initialized
      end

      def initialize!
        return false if initialized?

        self.initialized = true
        self.status = "initialized"
        save
      end

      def close!
        self.status = "closed"
        self.ended_at = Time.current
        save
      end

      # Message management
      def write(data)
        @messages << {
          data: data,
          direction: role == "server" ? "client" : "server",
          created_at: Time.current
        }
        @message_counter.increment
        self.messages_count = @message_counter.value
      end

      def read(data)
        @messages << {
          data: data,
          direction: role,
          created_at: Time.current
        }
        @message_counter.increment
        self.messages_count = @message_counter.value
      end

      def messages
        MessageCollection.new(@messages)
      end

      def subscriptions
        SubscriptionCollection.new(@subscriptions)
      end

      def resources
        ResourceCollection.new(@resources)
      end

      def sse_events
        SSEEventCollection.new(@sse_events)
      end

      # SSE event management
      def increment_sse_counter!
        new_value = @sse_counter.increment
        self.sse_event_counter = new_value
        save
        new_value
      end

      def store_sse_event(event_id, data, max_events = nil)
        max_events ||= max_stored_sse_events
        event = { event_id: event_id, data: data, created_at: Time.current }
        @sse_events << event

        # Maintain cache limit
        while @sse_events.size > max_events
          @sse_events.shift
        end

        event
      end

      def get_sse_events_after(last_event_id, limit = 50)
        @sse_events.select { |e| e[:event_id] > last_event_id }
                   .first(limit)
      end

      def cleanup_old_sse_events(max_age = 15.minutes)
        cutoff_time = Time.current - max_age
        @sse_events.delete_if { |e| e[:created_at] < cutoff_time }
      end

      # Calculates the maximum number of SSE events to store based on configuration
      # @return [Integer] The maximum number of events
      def max_stored_sse_events
        ActionMCP.configuration.max_stored_sse_events || 100
      end

      # Returns the SSE event retention period from configuration
      # @return [ActiveSupport::Duration] The retention period (default: 15 minutes)
      def sse_event_retention_period
        ActionMCP.configuration.sse_event_retention_period || 15.minutes
      end

      # Adapter methods
      def adapter
        ActionMCP::Server.server.pubsub
      end

      def session_key
        "action_mcp:session:#{id}"
      end

      # Capability methods
      def server_capabilities_payload
        {
          protocolVersion: ActionMCP::ProtocolVersion::LATEST_VERSION,
          serverInfo: server_info,
          capabilities: server_capabilities
        }
      end

      def set_protocol_version(version)
        version = ActionMCP::ProtocolVersion::LATEST_VERSION if ActionMCP.configuration.vibed_ignore_version
        self.protocol_version = version
        save
      end

      def store_client_info(info)
        self.client_info = info
      end

      def store_client_capabilities(capabilities)
        self.client_capabilities = capabilities
      end

      # Subscription management
      def resource_subscribe(uri)
        unless @subscriptions.any? { |s| s[:uri] == uri }
          @subscriptions << { uri: uri, created_at: Time.current }
        end
      end

      def resource_unsubscribe(uri)
        @subscriptions.delete_if { |s| s[:uri] == uri }
      end

      # Progress notification
      def send_progress_notification(progressToken:, progress:, total: nil, message: nil)
        handler = ActionMCP::Server::TransportHandler.new(self)
        handler.send_progress_notification(
          progressToken: progressToken,
          progress: progress,
          total: total,
          message: message
        )
      end

      # Registry management methods
      def register_tool(tool_class_or_name)
        tool_name = normalize_name(tool_class_or_name, :tool)
        return false unless tool_exists?(tool_name)

        self.tool_registry ||= []
        unless self.tool_registry.include?(tool_name)
          self.tool_registry << tool_name
          save!
          send_tools_list_changed_notification
        end
        true
      end

      def unregister_tool(tool_class_or_name)
        tool_name = normalize_name(tool_class_or_name, :tool)
        self.tool_registry ||= []

        return unless self.tool_registry.delete(tool_name)

        save!
        send_tools_list_changed_notification
      end

      def register_prompt(prompt_class_or_name)
        prompt_name = normalize_name(prompt_class_or_name, :prompt)
        return false unless prompt_exists?(prompt_name)

        self.prompt_registry ||= []
        unless self.prompt_registry.include?(prompt_name)
          self.prompt_registry << prompt_name
          save!
          send_prompts_list_changed_notification
        end
        true
      end

      def unregister_prompt(prompt_class_or_name)
        prompt_name = normalize_name(prompt_class_or_name, :prompt)
        self.prompt_registry ||= []

        return unless self.prompt_registry.delete(prompt_name)

        save!
        send_prompts_list_changed_notification
      end

      def register_resource_template(template_class_or_name)
        template_name = normalize_name(template_class_or_name, :resource_template)
        return false unless resource_template_exists?(template_name)

        self.resource_registry ||= []
        unless self.resource_registry.include?(template_name)
          self.resource_registry << template_name
          save!
          send_resources_list_changed_notification
        end
        true
      end

      def unregister_resource_template(template_class_or_name)
        template_name = normalize_name(template_class_or_name, :resource_template)
        self.resource_registry ||= []

        return unless self.resource_registry.delete(template_name)

        save!
        send_resources_list_changed_notification
      end

      def registered_tools
        (self.tool_registry || []).filter_map do |tool_name|
          ActionMCP::ToolsRegistry.find(tool_name)
        rescue StandardError
          nil
        end
      end

      def registered_prompts
        (self.prompt_registry || []).filter_map do |prompt_name|
          ActionMCP::PromptsRegistry.find(prompt_name)
        rescue StandardError
          nil
        end
      end

      def registered_resource_templates
        (self.resource_registry || []).filter_map do |template_name|
          ActionMCP::ResourceTemplatesRegistry.find(template_name)
        rescue StandardError
          nil
        end
      end

      private

      def normalize_name(class_or_name, type)
        case class_or_name
        when String
          class_or_name
        when Class
          case type
          when :tool
            class_or_name.tool_name
          when :prompt
            class_or_name.prompt_name
          when :resource_template
            class_or_name.capability_name
          end
        else
          raise ArgumentError, "Expected String or Class, got #{class_or_name.class}"
        end
      end

      def tool_exists?(tool_name)
        ActionMCP::ToolsRegistry.find(tool_name)
        true
      rescue ActionMCP::RegistryBase::NotFound
        false
      end

      def prompt_exists?(prompt_name)
        ActionMCP::PromptsRegistry.find(prompt_name)
        true
      rescue ActionMCP::RegistryBase::NotFound
        false
      end

      def resource_template_exists?(template_name)
        ActionMCP::ResourceTemplatesRegistry.find(template_name)
        true
      rescue ActionMCP::RegistryBase::NotFound
        false
      end

      def send_tools_list_changed_notification
        # Only send if server capabilities allow it
        return unless server_capabilities.dig("tools", "listChanged")

        write(JSON_RPC::Notification.new(method: "notifications/tools/list_changed"))
      end

      def send_prompts_list_changed_notification
        return unless server_capabilities.dig("prompts", "listChanged")

        write(JSON_RPC::Notification.new(method: "notifications/prompts/list_changed"))
      end

      def send_resources_list_changed_notification
        return unless server_capabilities.dig("resources", "listChanged")

        write(JSON_RPC::Notification.new(method: "notifications/resources/list_changed"))
      end

      public

      # Simple collection classes to mimic ActiveRecord associations
      class MessageCollection < Array
        def create!(attributes)
          self << attributes
          attributes
        end

        def order(field)
          # Simple ordering implementation
          sort_by { |msg| msg[field] || msg[field.to_s] }
        end
      end

      class SubscriptionCollection < Array
        def find_or_create_by(attributes)
          existing = find { |s| s[:uri] == attributes[:uri] }
          return existing if existing

          subscription = attributes.merge(created_at: Time.current)
          self << subscription
          subscription
        end

        def find_by(attributes)
          find { |s| s[:uri] == attributes[:uri] }
        end
      end

      class ResourceCollection < Array
      end

      class SSEEventCollection < Array
        def create!(attributes)
          self << attributes
          attributes
        end

        def count
          size
        end

        def where(condition, value)
          # Simple implementation for "event_id > ?" condition
          select { |e| e[:event_id] > value }
        end

        def order(field)
          sort_by { |e| e[field.is_a?(Hash) ? field.keys.first : field] }
        end

        def limit(n)
          first(n)
        end

        def delete_all
          clear
        end
      end
    end
  end
end
