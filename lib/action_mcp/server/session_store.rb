# frozen_string_literal: true

module ActionMCP
  module Server
    # Abstract interface for server session storage
    module SessionStore
      # Create a new session
      def create_session(session_id = nil, attributes = {})
        raise NotImplementedError, "#{self.class} must implement #create_session"
      end

      # Load session by ID
      def load_session(session_id)
        raise NotImplementedError, "#{self.class} must implement #load_session"
      end

      # Save/update session
      def save_session(session)
        raise NotImplementedError, "#{self.class} must implement #save_session"
      end

      # Delete session
      def delete_session(session_id)
        raise NotImplementedError, "#{self.class} must implement #delete_session"
      end

      # Check if session exists
      def session_exists?(session_id)
        raise NotImplementedError, "#{self.class} must implement #session_exists?"
      end

      # Find sessions by criteria
      def find_sessions(criteria = {})
        raise NotImplementedError, "#{self.class} must implement #find_sessions"
      end

      # Cleanup expired sessions
      def cleanup_expired_sessions(older_than: 24.hours.ago)
        raise NotImplementedError, "#{self.class} must implement #cleanup_expired_sessions"
      end
    end

    # Volatile session store for development (data lost on restart)
    class VolatileSessionStore
      include SessionStore

      def initialize
        @sessions = Concurrent::Hash.new
      end

      def create_session(session_id = nil, attributes = {})
        session_id ||= SecureRandom.hex(6)

        session_data = {
          id: session_id,
          status: "pre_initialize",
          initialized: false,
          role: "server",
          messages_count: 0,
          sse_event_counter: 0,
          created_at: Time.current,
          updated_at: Time.current
        }.merge(attributes)

        session = MemorySession.new(session_data, self)

        # Initialize server info and capabilities if server role
        if session.role == "server"
          session.server_info = {
            name: ActionMCP.configuration.name,
            version: ActionMCP.configuration.version
          }
          session.server_capabilities = ActionMCP.configuration.capabilities

          # Initialize registries
          session.tool_registry = ActionMCP.configuration.filtered_tools.map(&:name)
          session.prompt_registry = ActionMCP.configuration.filtered_prompts.map(&:name)
          session.resource_registry = ActionMCP.configuration.filtered_resources.map(&:name)
        end

        @sessions[session_id] = session
        session
      end

      def load_session(session_id)
        session = @sessions[session_id]
        if session
          session.instance_variable_set(:@new_record, false)
        end
        session
      end

      def save_session(session)
        @sessions[session.id] = session
      end

      def delete_session(session_id)
        @sessions.delete(session_id)
      end

      def session_exists?(session_id)
        @sessions.key?(session_id)
      end

      def find_sessions(criteria = {})
        sessions = @sessions.values

        # Filter by status
        if criteria[:status]
          sessions = sessions.select { |s| s.status == criteria[:status] }
        end

        # Filter by role
        if criteria[:role]
          sessions = sessions.select { |s| s.role == criteria[:role] }
        end

        sessions
      end

      def cleanup_expired_sessions(older_than: 24.hours.ago)
        expired_ids = @sessions.select do |_id, session|
          session.updated_at < older_than
        end.keys

        expired_ids.each { |id| @sessions.delete(id) }
        expired_ids.count
      end

      def clear_all
        @sessions.clear
      end

      def session_count
        @sessions.size
      end
    end

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

      def store_sse_event(event_id, data, max_events = 100)
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
          protocolVersion: ActionMCP::PROTOCOL_VERSION,
          serverInfo: server_info,
          capabilities: server_capabilities
        }
      end

      def set_protocol_version(version)
        version = ActionMCP::PROTOCOL_VERSION if ActionMCP.configuration.vibed_ignore_version
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

    # ActiveRecord-backed session store (default for production)
    class ActiveRecordSessionStore
      include SessionStore

      def create_session(session_id = nil, attributes = {})
        session = ActionMCP::Session.new(attributes)
        session.id = session_id if session_id
        session.save!
        session
      end

      def load_session(session_id)
        ActionMCP::Session.find_by(id: session_id)
      end

      def save_session(session)
        session.save! if session.is_a?(ActionMCP::Session)
      end

      def delete_session(session_id)
        ActionMCP::Session.find_by(id: session_id)&.destroy
      end

      def session_exists?(session_id)
        ActionMCP::Session.exists?(id: session_id)
      end

      def find_sessions(criteria = {})
        scope = ActionMCP::Session.all

        scope = scope.where(status: criteria[:status]) if criteria[:status]
        scope = scope.where(role: criteria[:role]) if criteria[:role]

        scope
      end

      def cleanup_expired_sessions(older_than: 24.hours.ago)
        ActionMCP::Session.where("updated_at < ?", older_than).destroy_all
      end
    end

    # Test session store that tracks all operations for assertions
    class TestSessionStore < VolatileSessionStore
      attr_reader :operations, :created_sessions, :loaded_sessions,
                  :saved_sessions, :deleted_sessions, :notifications_sent

      def initialize
        super
        @operations = Concurrent::Array.new
        @created_sessions = Concurrent::Array.new
        @loaded_sessions = Concurrent::Array.new
        @saved_sessions = Concurrent::Array.new
        @deleted_sessions = Concurrent::Array.new
        @notifications_sent = Concurrent::Array.new
        @notification_callbacks = Concurrent::Array.new
      end

      def create_session(session_id = nil, attributes = {})
        session = super
        @operations << { type: :create, session_id: session.id, attributes: attributes }
        @created_sessions << session.id
        
        # Hook into the session's write method to capture notifications
        test_store = self
        original_write = session.method(:write)
        session.define_singleton_method(:write) do |data|
          result = original_write.call(data)
          
          # Track progress notifications
          if data.is_a?(JSON_RPC::Notification) && data.method == "notifications/progress"
            test_store.track_notification(data)
          end
          
          result
        end
        
        session
      end

      def load_session(session_id)
        session = super
        @operations << { type: :load, session_id: session_id, found: !session.nil? }
        @loaded_sessions << session_id if session
        session
      end

      def save_session(session)
        super
        @operations << { type: :save, session_id: session.id }
        @saved_sessions << session.id
      end

      def delete_session(session_id)
        result = super
        @operations << { type: :delete, session_id: session_id }
        @deleted_sessions << session_id
        result
      end

      def cleanup_expired_sessions(older_than: 24.hours.ago)
        count = super
        @operations << { type: :cleanup, older_than: older_than, count: count }
        count
      end

      # Test helper methods
      def session_created?(session_id)
        @created_sessions.include?(session_id)
      end

      def session_loaded?(session_id)
        @loaded_sessions.include?(session_id)
      end

      def session_saved?(session_id)
        @saved_sessions.include?(session_id)
      end

      def session_deleted?(session_id)
        @deleted_sessions.include?(session_id)
      end

      def operation_count(type = nil)
        if type
          @operations.count { |op| op[:type] == type }
        else
          @operations.size
        end
      end

      # Notification tracking methods
      def track_notification(notification)
        @notifications_sent << notification
        @notification_callbacks.each { |cb| cb.call(notification) }
      end
      
      def on_notification(&block)
        @notification_callbacks << block
      end
      
      def notifications_for_token(token)
        @notifications_sent.select do |n|
          n.params[:progressToken] == token
        end
      end
      
      def clear_notifications
        @notifications_sent.clear
      end
      
      def reset_tracking!
        @operations.clear
        @created_sessions.clear
        @loaded_sessions.clear
        @saved_sessions.clear
        @deleted_sessions.clear
        @notifications_sent.clear
        @notification_callbacks.clear
      end
    end

    # Factory for creating session stores
    class SessionStoreFactory
      def self.create(type = nil, **options)
        type ||= default_type

        case type.to_sym
        when :volatile, :memory
          VolatileSessionStore.new
        when :active_record, :persistent
          ActiveRecordSessionStore.new
        when :test
          TestSessionStore.new
        else
          raise ArgumentError, "Unknown session store type: #{type}"
        end
      end

      def self.default_type
        if Rails.env.test?
          :volatile  # Use volatile for tests unless explicitly using :test
        elsif Rails.env.production?
          :active_record
        else
          :volatile
        end
      end
    end
  end
end
