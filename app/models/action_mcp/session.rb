# frozen_string_literal: true

# == Schema Information
#
# Table name: action_mcp_sessions
#
#  id                     :string           not null, primary key
#  authentication_method  :string           default("none")
#  client_capabilities    :json
#  client_info            :json
#  consents               :json             not null
#  ended_at               :datetime
#  initialized            :boolean          default(FALSE), not null
#  messages_count         :integer          default(0), not null
#  oauth_access_token     :string
#  oauth_refresh_token    :string
#  oauth_token_expires_at :datetime
#  oauth_user_context     :json
#  prompt_registry        :json
#  protocol_version       :string
#  resource_registry      :json
#  role                   :string           default("server"), not null
#  server_capabilities    :json
#  server_info            :json
#  sse_event_counter      :integer          default(0), not null
#  status                 :string           default("pre_initialize"), not null
#  tool_registry          :json
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_action_mcp_sessions_on_authentication_method   (authentication_method)
#  index_action_mcp_sessions_on_oauth_access_token      (oauth_access_token) UNIQUE
#  index_action_mcp_sessions_on_oauth_token_expires_at  (oauth_token_expires_at)
#
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

    has_many :sse_events,
             class_name: "ActionMCP::Session::SSEEvent",
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
      {
        protocolVersion: protocol_version || ActionMCP::DEFAULT_PROTOCOL_VERSION,
        serverInfo: server_info,
        capabilities: server_capabilities
      }
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

    # Atomically increments the SSE event counter and returns the new value.
    # This ensures unique, sequential IDs for SSE events within the session.
    # @return [Integer] The new value of the counter.
    def increment_sse_counter!
      # Use update_counters for an atomic increment operation
      self.class.update_counters(id, sse_event_counter: 1)
      # Reload to get the updated value (update_counters doesn't update the instance)
      reload.sse_event_counter
    end

    # Stores an SSE event for potential resumption
    # @param event_id [Integer] The event ID
    # @param data [Hash, String] The event data
    # @param max_events [Integer] Maximum number of events to store (oldest events are removed when exceeded)
    # @return [ActionMCP::Session::SSEEvent] The created event
    def store_sse_event(event_id, data, max_events = 100)
      # Create the SSE event record
      event = sse_events.create!(
        event_id: event_id,
        data: data
      )

      # Maintain cache limit by removing oldest events if needed
      count = sse_events.count
      excess = count - max_events
      sse_events.order(event_id: :asc).limit(excess).delete_all if excess.positive?

      event
    end

    # Retrieves SSE events after a given ID
    # @param last_event_id [Integer] The ID to retrieve events after
    # @param limit [Integer] Maximum number of events to return
    # @return [Array<ActionMCP::Session::SSEEvent>] The events
    def get_sse_events_after(last_event_id, limit = 50)
      sse_events.where("event_id > ?", last_event_id)
                .order(event_id: :asc)
                .limit(limit)
    end

    # Cleans up old SSE events
    # @param max_age [ActiveSupport::Duration] Maximum age of events to keep
    # @return [Integer] Number of events removed
    def cleanup_old_sse_events(max_age = 15.minutes)
      cutoff_time = Time.current - max_age
      events_to_delete = sse_events.where("created_at < ?", cutoff_time)
      count = events_to_delete.count
      events_to_delete.destroy_all
      count
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

    # Calculates the retention period for SSE events based on configuration
    # @return [ActiveSupport::Duration] The retention period
    def sse_event_retention_period
      ActionMCP.configuration.sse_event_retention_period || 15.minutes
    end

    # Calculates the maximum number of SSE events to store based on configuration
    # @return [Integer] The maximum number of events
    def max_stored_sse_events
      ActionMCP.configuration.max_stored_sse_events || 100
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

    # OAuth Session Management
    # Required by MCP 2025-03-26 specification for session binding

    # Store OAuth token and user context in session
    def store_oauth_token(access_token:, expires_at:, refresh_token: nil, user_context: {})
      update!(
        oauth_access_token: access_token,
        oauth_refresh_token: refresh_token,
        oauth_token_expires_at: expires_at,
        oauth_user_context: user_context,
        authentication_method: "oauth"
      )
    end

    # Retrieve OAuth token information
    def oauth_token_info
      return nil unless oauth_access_token

      {
        access_token: oauth_access_token,
        refresh_token: oauth_refresh_token,
        expires_at: oauth_token_expires_at,
        user_context: oauth_user_context || {},
        authentication_method: authentication_method
      }
    end

    # Check if OAuth token is valid and not expired
    def oauth_token_valid?
      return false unless oauth_access_token
      return true unless oauth_token_expires_at

      oauth_token_expires_at > Time.current
    end

    # Clear OAuth token data
    def clear_oauth_token!
      update!(
        oauth_access_token: nil,
        oauth_refresh_token: nil,
        oauth_token_expires_at: nil,
        oauth_user_context: nil,
        authentication_method: "none"
      )
    end

    # Update OAuth token (for refresh flow)
    def update_oauth_token(access_token:, expires_at:, refresh_token: nil)
      update!(
        oauth_access_token: access_token,
        oauth_refresh_token: refresh_token,
        oauth_token_expires_at: expires_at
      )
    end

    # Get user information from OAuth context
    def oauth_user
      return nil unless oauth_user_context.is_a?(Hash)

      OpenStruct.new(oauth_user_context)
    end

    # Check if session is authenticated via OAuth
    def oauth_authenticated?
      authentication_method == "oauth" && oauth_token_valid?
    end

    # Find session by OAuth access token (class method)
    def self.find_by_oauth_token(access_token)
      find_by(oauth_access_token: access_token)
    end

    # Find sessions with expired OAuth tokens (class method)
    def self.with_expired_oauth_tokens
      where("oauth_token_expires_at IS NOT NULL AND oauth_token_expires_at < ?", Time.current)
    end

    # Cleanup expired OAuth tokens (class method)
    def self.cleanup_expired_oauth_tokens
      with_expired_oauth_tokens.update_all(
        oauth_access_token: nil,
        oauth_refresh_token: nil,
        oauth_token_expires_at: nil,
        oauth_user_context: nil,
        authentication_method: "none"
      )
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
      self.server_info = {
        name: ActionMCP.configuration.name,
        version: ActionMCP.configuration.version
      }
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
  end
end
