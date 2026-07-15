# frozen_string_literal: true

module ActionMCP
  module Server
    # Base session object that mimics ActiveRecord Session with common functionality
    class BaseSession
      attr_accessor :id, :status, :initialized, :role, :messages_count,
                    :protocol_version, :client_info,
                    :client_capabilities, :server_info, :server_capabilities,
                    :tool_registry, :prompt_registry, :resource_registry,
                    :created_at, :updated_at, :ended_at, :last_event_id,
                    :session_data, :consents

      def initialize(attributes = {}, store = nil)
        @store = store
        @messages = Concurrent::Array.new
        @subscriptions = Concurrent::Array.new
        @message_counter = Concurrent::AtomicFixnum.new(0)
        @new_record = true

        # Initialize consents and session_data as empty hashes if not provided
        @consents = {}
        @session_data = {}

        attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
      end

      # ActiveRecord-like interface
      def new_record?
        @new_record
      end

      def persisted?
        !@new_record
      end

      def save
        self.updated_at = Time.current
        @store&.save_session(self)
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
        @store&.delete_session(id)
      end

      def reload
        self
      end

      def initialized?
        initialized
      end

      def begin_initialization!
        return false unless status == "pre_initialize" && !initialized?

        self.status = "initializing"
        save
      end

      def initialize!
        return false unless status == "initializing" && !initialized?

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
        record_message(data, writer_role)
      end

      def read(data)
        record_message(data, role)
      end

      def messages
        MessageCollection.new(@messages)
      end

      def subscriptions
        SubscriptionCollection.new(@subscriptions)
      end

      def cancel_in_flight_request(request_id)
        return if request_id.nil?

        request = received_requests_with_id(request_id).find do |message|
          !message[:request_acknowledged] && !message[:request_cancelled]
        end
        return if request && message_payload(request)[:method] == JsonRpcHandlerBase::Methods::INITIALIZE

        request&.tap { |message| message[:request_cancelled] = true }
      end

      def client_request_for_progress(progress_token)
        return if progress_token.nil?

        issued_client_requests.find do |request|
          message_payload(request).dig(:params, :_meta, :progressToken) == progress_token &&
            client_request_accepts_progress?(request)
        end
      end

      def client_request_for_task(task_id)
        return unless task_id.is_a?(String) && task_id.present?

        response = @messages.reverse_each.find do |message|
          message[:direction] == role &&
            message_payload(message).dig(:result, :task, :taskId) == task_id
        end
        return unless response

        response_id = message_payload(response)[:id]
        issued_client_requests.find do |request|
          payload = message_payload(request)
          payload[:id] == response_id && payload.dig(:params, :task).is_a?(Hash)
        end
      end

      # Capability methods
      def server_capabilities_payload
        payload = {
          protocolVersion: ActionMCP::LATEST_VERSION,
          serverInfo: server_info,
          capabilities: capabilities_for_protocol(server_capabilities)
        }
        # Add instructions at top level if configured
        instructions = ActionMCP.configuration.instructions
        payload[:instructions] = instructions if instructions
        payload
      end

      def set_protocol_version(version)
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
        return if @subscriptions.any? { |s| s[:uri] == uri }

        @subscriptions << { uri: uri, created_at: Time.current }
      end

      def resource_unsubscribe(uri)
        @subscriptions.delete_if { |s| s[:uri] == uri }
      end

      def resource_subscribed?(uri)
        @subscriptions.any? { |subscription| subscription[:uri] == uri }
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

      # Consent management methods
      def consent_granted_for?(key)
        consents_hash = consents.is_a?(String) ? JSON.parse(consents) : consents
        consents_hash ||= {}
        consents_hash[key] == true
      end

      def grant_consent(key)
        consents_hash = consents.is_a?(String) ? JSON.parse(consents) : consents
        consents_hash ||= {}
        consents_hash[key] = true
        self.consents = consents_hash
        save!
      end

      def revoke_consent(key)
        consents_hash = consents.is_a?(String) ? JSON.parse(consents) : consents
        consents_hash ||= {}
        consents_hash.delete(key)
        self.consents = consents_hash
        save!
      end

      private

      CLIENT_REQUEST_METHODS = %w[sampling/createMessage elicitation/create].freeze
      TERMINAL_CLIENT_TASK_STATUSES = %w[cancelled completed failed].freeze

      def record_message(data, direction)
        payload = data.respond_to?(:to_h) ? data.to_h : data
        entry = {
          data: data,
          direction: direction,
          request_acknowledged: false,
          request_cancelled: false,
          is_ping: payload.is_a?(Hash) && (payload[:method] || payload["method"]) == "ping",
          created_at: Time.current
        }
        @messages << entry
        acknowledge_request(entry)
        @message_counter.increment
        self.messages_count = @message_counter.value
        entry
      end

      def acknowledge_request(response)
        payload = message_payload(response)
        return unless payload.key?(:id) && (payload.key?(:result) || payload.key?(:error))

        request = @messages.reverse_each.find do |message|
          next if message.equal?(response) || message[:direction] == response[:direction]

          request_payload = message_payload(message)
          request_payload.key?(:method) && request_payload[:id] == payload[:id]
        end
        return unless request

        request[:request_acknowledged] = true
        response[:is_ping] = request[:is_ping]
      end

      def received_requests_with_id(request_id)
        @messages.reverse_each.select do |message|
          payload = message_payload(message)
          message[:direction] == role && payload.key?(:method) && payload[:id] == request_id
        end
      end

      def issued_client_requests
        @messages.reverse_each.select do |message|
          payload = message_payload(message)
          message[:direction] == writer_role && CLIENT_REQUEST_METHODS.include?(payload[:method])
        end
      end

      def client_request_accepts_progress?(request)
        return true unless request[:request_acknowledged]

        request_id = message_payload(request)[:id]
        response = @messages.reverse_each.find do |message|
          payload = message_payload(message)
          message[:direction] == role && payload[:id] == request_id && payload.key?(:result)
        end
        task = message_payload(response).dig(:result, :task) if response
        return false unless task.is_a?(Hash) && task[:taskId].is_a?(String)

        latest_status = @messages.reverse_each.filter_map do |message|
          payload = message_payload(message)
          next unless message[:direction] == role
          next unless payload[:method] == JsonRpcHandlerBase::Methods::NOTIFICATIONS_TASKS_STATUS
          next unless payload.dig(:params, :taskId) == task[:taskId]

          payload.dig(:params, :status)
        end.first

        !TERMINAL_CLIENT_TASK_STATUSES.include?(latest_status || task[:status])
      end

      def message_payload(message)
        data = message[:data]
        data = data.to_h if data.respond_to?(:to_h)
        data.is_a?(Hash) ? data.with_indifferent_access : {}.with_indifferent_access
      end

      def writer_role
        role == "server" ? "client" : "server"
      end

      def capabilities_for_protocol(capabilities)
        capabilities ? capabilities.deep_dup : {}
      end

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

      # Collection classes
      class MessageCollection < Array
        def create!(attributes)
          self << attributes
          attributes
        end

        def order(field)
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
    end
  end
end
