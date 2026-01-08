# frozen_string_literal: true

# <rails-lens:schema:begin>
# table = "action_mcp_sessions"
# database_dialect = "SQLite"
#
# columns = [
#   { name = "id", type = "string", primary_key = true, nullable = false },
#   { name = "role", type = "string", nullable = false, default = "server" },
#   { name = "status", type = "string", nullable = false, default = "pre_initialize" },
#   { name = "ended_at", type = "datetime", nullable = true },
#   { name = "protocol_version", type = "string", nullable = true },
#   { name = "server_capabilities", type = "json", nullable = true },
#   { name = "client_capabilities", type = "json", nullable = true },
#   { name = "server_info", type = "json", nullable = true },
#   { name = "client_info", type = "json", nullable = true },
#   { name = "initialized", type = "boolean", nullable = false, default = "0" },
#   { name = "messages_count", type = "integer", nullable = false, default = "0" },
#   { name = "sse_event_counter", type = "integer", nullable = false, default = "0" },
#   { name = "tool_registry", type = "json", nullable = true, default = "[]" },
#   { name = "prompt_registry", type = "json", nullable = true, default = "[]" },
#   { name = "resource_registry", type = "json", nullable = true, default = "[]" },
#   { name = "created_at", type = "datetime", nullable = false },
#   { name = "updated_at", type = "datetime", nullable = false },
#   { name = "consents", type = "json", nullable = false, default = "{}" }
# ]
#
# == Notes
# - Association 'messages' has N+1 query risk. Consider using includes/preload
# - Association 'subscriptions' has N+1 query risk. Consider using includes/preload
# - Association 'resources' has N+1 query risk. Consider using includes/preload
# - Association 'sse_events' has N+1 query risk. Consider using includes/preload
# - Column 'protocol_version' should probably have NOT NULL constraint
# - Column 'server_capabilities' should probably have NOT NULL constraint
# - Column 'client_capabilities' should probably have NOT NULL constraint
# - Column 'server_info' should probably have NOT NULL constraint
# - Column 'client_info' should probably have NOT NULL constraint
# - Column 'tool_registry' should probably have NOT NULL constraint
# - Column 'prompt_registry' should probably have NOT NULL constraint
# - Column 'resource_registry' should probably have NOT NULL constraint
# - String column 'id' has no length limit - consider adding one
# - String column 'role' has no length limit - consider adding one
# - String column 'status' has no length limit - consider adding one
# - String column 'protocol_version' has no length limit - consider adding one
# - Column 'status' is commonly used in queries - consider adding an index
# <rails-lens:schema:end>
module ActionMCP
  ##
  # Represents an MCP session, which is a connection between a client and a server.
  # Its role is to manage the communication channel and store information about the session,
  # such as client and server capabilities, protocol version, and session status.
  # It also manages the association with messages and subscriptions related to the session.
  class Session < ApplicationRecord
    after_initialize do
      self.consents = {} if consents == "{}" || consents.nil?
    end

    include MCPConsoleHelpers
    attribute :id, :string, default: -> { SecureRandom.hex(6) }
    has_many :messages,
             class_name: "ActionMCP::Session::Message",
             foreign_key: "session_id",
             dependent: :delete_all,
             inverse_of: :session
    has_many :subscriptions,
             class_name: "ActionMCP::Session::Subscription",
             foreign_key: "session_id",
             dependent: :delete_all,
             inverse_of: :session
    has_many :resources,
             class_name: "ActionMCP::Session::Resource",
             foreign_key: "session_id",
             dependent: :delete_all,
             inverse_of: :session

    has_many :tasks,
             class_name: "ActionMCP::Session::Task",
             foreign_key: "session_id",
             dependent: :delete_all,
             inverse_of: :session

    scope :pre_initialize, -> { where(status: "pre_initialize") }
    scope :closed, -> { where(status: "closed") }
    scope :without_messages, -> { includes(:messages).where(action_mcp_session_messages: { id: nil }) }

    scope :from_server, -> { where(role: "server") }
    scope :from_client, -> { where(role: "client") }
    # Initialize with default registries
    before_create :initialize_registries
    before_create :set_server_info, if: -> { role == "server" }
    before_create :set_server_capabilities, if: -> { role == "server" }

    validates :protocol_version, inclusion: { in: ActionMCP::SUPPORTED_VERSIONS }, allow_nil: true

    def close!
      dummy_callback = ->(*) { } # this callback seem broken
      adapter.unsubscribe(session_key, dummy_callback)
      if messages_count.zero?
        # if there are no messages, we can delete the session immediately
        destroy
        nil
      else
        update!(status: "closed", ended_at: Time.zone.now)
        subscriptions.delete_all # delete all subscriptions
      end
    end

    # MESSAGING dispatch
    def write(data)
      if data.is_a?(JSON_RPC::Request) || data.is_a?(JSON_RPC::Response) || data.is_a?(JSON_RPC::Notification)
        data = data.to_json
      end
      data = MultiJson.dump(data) if data.is_a?(Hash)

      messages.create!(data: data, direction: writer_role)
    end

    def read(data)
      messages.create!(data: data, direction: role)
    end

    def session_key
      "action_mcp:session:#{id}"
    end

    def adapter
      @adapter ||= ActionMCP::Server.server.pubsub
    end

    def set_protocol_version(version)
      update(protocol_version: version)
    end

    def store_client_info(info)
      self.client_info = info
    end

    def store_client_capabilities(capabilities)
      self.client_capabilities = capabilities
    end

    def server_capabilities_payload
      payload = {
        protocolVersion: protocol_version || ActionMCP::DEFAULT_PROTOCOL_VERSION,
        serverInfo: server_info,
        capabilities: server_capabilities
      }
      # Add instructions at top level if configured
      instructions = ActionMCP.configuration.instructions
      payload[:instructions] = instructions if instructions
      payload
    end

    def server_capabilities
      parsed_json_attribute(super)
    end

    def server_capabilities=(value)
      super(parsed_json_attribute(value))
    end

    def initialize!
      # update the session initialized to true
      return false if initialized?

      self.initialized = true
      self.status = "initialized"
      save
    end

    def send_ping!
      Session.logger.silence do
        write(JSON_RPC::Request.new(id: Time.now.to_i, method: "ping"))
      end
    end

    def resource_subscribe(uri)
      subscriptions.find_or_create_by(uri: uri)
    end

    def resource_unsubscribe(uri)
      subscriptions.find_by(uri: uri)&.destroy
    end

    def send_progress_notification(progressToken:, progress:, total: nil, message: nil)
      # Create a transport handler to send the notification
      handler = ActionMCP::Server::TransportHandler.new(self)
      handler.send_progress_notification(
        progressToken: progressToken,
        progress: progress,
        total: total,
        message: message
      )
    end

    def send_progress_notification_legacy(token:, value:, message: nil)
      send_progress_notification(progressToken: token, progress: value, message: message)
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

    # Get registered items for this session
    def registered_tools
      # Special case: ['*'] means use all available tools dynamically
      if tool_registry == [ "*" ]
        # filtered_tools returns a RegistryScope with Item objects, need to extract the klass
        ActionMCP.configuration.filtered_tools.map(&:klass)
      else
        (self.tool_registry || []).filter_map do |tool_name|
          ActionMCP::ToolsRegistry.find(tool_name)
        rescue StandardError
          nil
        end
      end
    end

    def registered_prompts
      if prompt_registry == [ "*" ]
        # filtered_prompts returns a RegistryScope with Item objects, need to extract the klass
        ActionMCP.configuration.filtered_prompts.map(&:klass)
      else
        (self.prompt_registry || []).filter_map do |prompt_name|
          ActionMCP::PromptsRegistry.find(prompt_name)
        rescue StandardError
          nil
        end
      end
    end

    def registered_resource_templates
      if resource_registry == [ "*" ]
        # filtered_resources returns a RegistryScope with Item objects, need to extract the klass
        ActionMCP.configuration.filtered_resources.map(&:klass)
      else
        (self.resource_registry || []).filter_map do |template_name|
          ActionMCP::ResourceTemplatesRegistry.find(template_name)
        rescue StandardError
          nil
        end
      end
    end

    # Helper methods to check if using all capabilities
    def uses_all_tools?
      tool_registry == [ "*" ]
    end

    def uses_all_prompts?
      prompt_registry == [ "*" ]
    end

    def uses_all_resources?
      resource_registry == [ "*" ]
    end


    # Consent management methods as per MCP specification
    # These methods manage user consents for tools and resources

    # Checks if consent has been granted for a specific key
    # @param key [String] The consent key (e.g., tool name or resource URI)
    # @return [Boolean] true if consent is granted, false otherwise
    def consent_granted_for?(key)
      consents_hash = consents.is_a?(String) ? JSON.parse(consents) : consents
      consents_hash&.key?(key) && consents_hash[key] == true
    end

    # Grants consent for a specific key
    # @param key [String] The consent key to grant
    # @return [Boolean] true if saved successfully
    def grant_consent(key)
      self.consents = JSON.parse(consents) if consents.is_a?(String)
      self.consents ||= {}
      self.consents[key] = true
      save!
    end

    # Revokes consent for a specific key
    # @param key [String] The consent key to revoke
    # @return [void]
    def revoke_consent(key)
      self.consents = JSON.parse(self.consents) if self.consents.is_a?(String)
      return unless consents&.key?(key)

      consents.delete(key)
      save!
    end

    private

    # if this session is from a server, the writer is the client
    def writer_role
      role == "server" ? "client" : "server"
    end

    # This will keep the version and name of the server when this session was created
    def set_server_info
      self.server_info = ActionMCP.configuration.server_info
    end

    # This can be overridden by the application in future versions
    def set_server_capabilities
      self.server_capabilities ||= ActionMCP.configuration.capabilities
    end

    def initialize_registries
      # Default to using all available capabilities with '*'
      self.tool_registry = [ "*" ]
      self.prompt_registry = [ "*" ]
      self.resource_registry = [ "*" ]
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

    def parsed_json_attribute(value)
      return value unless value.is_a?(String)

      JSON.parse(value)
    rescue JSON::ParserError
      value
    end
  end
end
