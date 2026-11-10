# frozen_string_literal: true

# <rails-lens:schema:begin>
# table = "action_mcp_sessions"
# database_dialect = "SQLite"
#
# columns = [
#   { name = "id", type = "string", pk = true, null = false },
#   { name = "client_capabilities", type = "json" },
#   { name = "client_info", type = "json" },
#   { name = "consents", type = "json", null = false, default = "{}" },
#   { name = "session_data", type = "json", null = false, default = "{}" },
#   { name = "created_at", type = "datetime", null = false },
#   { name = "ended_at", type = "datetime" },
#   { name = "initialized", type = "boolean", null = false },
#   { name = "messages_count", type = "integer", null = false, default = 0 },
#   { name = "prompt_registry", type = "json", default = "[]" },
#   { name = "protocol_version", type = "string" },
#   { name = "resource_registry", type = "json", default = "[]" },
#   { name = "role", type = "string", null = false, default = "server" },
#   { name = "server_capabilities", type = "json" },
#   { name = "server_info", type = "json" },
#   { name = "status", type = "string", null = false, default = "pre_initialize" },
#   { name = "tool_registry", type = "json", default = "[]" },
#   { name = "updated_at", type = "datetime", null = false }
# ]
#
# [callbacks]
# before_create = [{ method = "initialize_registries" }, { method = "set_server_info", if = ["proc"] }, { method = "set_server_capabilities", if = ["proc"] }]
#
# notes = ["messages:N_PLUS_ONE", "subscriptions:N_PLUS_ONE", "tasks:N_PLUS_ONE", "client_capabilities:NOT_NULL", "client_info:NOT_NULL", "prompt_registry:NOT_NULL", "protocol_version:NOT_NULL", "resource_registry:NOT_NULL", "server_capabilities:NOT_NULL", "server_info:NOT_NULL", "tool_registry:NOT_NULL", "id:LIMIT", "protocol_version:LIMIT", "role:LIMIT", "status:LIMIT", "status:INDEX"]
# <rails-lens:schema:end>
module ActionMCP
  ##
  # Represents an MCP session, which is a connection between a client and a server.
  # Its role is to manage the communication channel and store information about the session,
  # such as client and server capabilities, protocol version, and session status.
  # It also manages the association with messages and subscriptions related to the session.
  class Session < ApplicationRecord
    include MCPConsoleHelpers
    include Server::SessionRegistries
    attribute :id, :string, default: -> { SecureRandom.hex(16) }
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
      data = MultiJSON.generate(data) if data.is_a?(Hash)

      messages.create!(data: data, direction: writer_role)
    end

    def read(data)
      messages.create!(data: data, direction: role)
    end

    # Marks an in-flight request received from the peer as cancelled. JSON-RPC
    # IDs are scoped by direction, so an outbound request with the same ID must
    # never be selected here.
    def cancel_in_flight_request(request_id)
      return if request_id.nil?

      request = received_requests_with_id(request_id).find do |message|
        !message.request_acknowledged? && !message.request_cancelled?
      end
      return if request&.rpc_method == JsonRpcHandlerBase::Methods::INITIALIZE

      request&.tap { |message| message.update!(request_cancelled: true) }
    end

    # Locates the server-originated client request associated with a progress
    # token. This is intentionally limited to MCP client request methods that
    # ActionMCP can issue.
    def client_request_for_progress(progress_token)
      return if progress_token.nil?

      issued_client_requests.find do |request|
        request.data.dig("params", "_meta", "progressToken") == progress_token &&
          client_request_accepts_progress?(request)
      end
    end

    # Locates the task-augmented client request which created +task_id+.
    def client_request_for_task(task_id)
      return unless task_id.is_a?(String) && task_id.present?

      response = messages.responses.where(direction: role).order(created_at: :desc).find do |message|
        message.data.dig("result", "task", "taskId") == task_id
      end
      return unless response

      issued_client_requests_with_id(response.data["id"]).find do |request|
        request.data.dig("params", "task").is_a?(Hash)
      end
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
        capabilities: capabilities_for_protocol(server_capabilities)
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

    def capabilities_for_protocol(capabilities)
      parsed = parsed_json_attribute(capabilities)
      parsed ? parsed.deep_dup : {}
    end

    def begin_initialization!
      return false unless status == "pre_initialize" && !initialized?

      update(status: "initializing")
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

    def resource_subscribed?(uri)
      subscriptions.exists?(uri: uri)
    end

    # Consent management methods as per MCP specification
    # These methods manage user consents for tools and resources

    def consents
      value = super
      return {} if value.nil? || value == ""

      value.is_a?(String) ? JSON.parse(value) : value
    end

    # Checks if consent has been granted for a specific key
    # @param key [String] The consent key (e.g., tool name or resource URI)
    # @return [Boolean] true if consent is granted, false otherwise
    def consent_granted_for?(key)
      consents[key] == true
    end

    # Grants consent for a specific key
    # @param key [String] The consent key to grant
    # @return [Boolean] true if saved successfully
    def grant_consent(key)
      update!(consents: consents.merge(key => true))
    end

    # Revokes consent for a specific key
    # @param key [String] The consent key to revoke
    # @return [void]
    def revoke_consent(key)
      return unless consents.key?(key)

      update!(consents: consents.except(key))
    end

    private

    CLIENT_REQUEST_METHODS = %w[sampling/createMessage elicitation/create].freeze
    TERMINAL_CLIENT_TASK_STATUSES = %w[cancelled completed failed].freeze

    def received_requests_with_id(request_id)
      messages.requests
        .where(direction: role, jsonrpc_id: request_id.to_s)
        .order(created_at: :desc)
        .select { |message| message.data["id"] == request_id }
    end

    def issued_client_requests
      messages.requests.where(direction: writer_role).order(created_at: :desc).select do |message|
        CLIENT_REQUEST_METHODS.include?(message.rpc_method)
      end
    end

    def issued_client_requests_with_id(request_id)
      issued_client_requests.select { |message| message.data["id"] == request_id }
    end

    def client_request_accepts_progress?(request)
      return true unless request.request_acknowledged?

      response = messages.responses
        .where(direction: role, jsonrpc_id: request.jsonrpc_id)
        .order(created_at: :desc)
        .find { |message| message.data["id"] == request.data["id"] }
      task = response&.data&.dig("result", "task")
      return false unless task.is_a?(Hash) && task["taskId"].is_a?(String)

      latest_status = messages.notifications.where(direction: role).order(created_at: :desc).filter_map do |message|
        params = message.data["params"]
        next unless message.data["method"] == JsonRpcHandlerBase::Methods::NOTIFICATIONS_TASKS_STATUS
        next unless params.is_a?(Hash) && params["taskId"] == task["taskId"]

        params["status"]
      end.first

      !TERMINAL_CLIENT_TASK_STATUSES.include?(latest_status || task["status"])
    end

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

    def parsed_json_attribute(value)
      return value unless value.is_a?(String)

      JSON.parse(value)
    rescue JSON::ParserError
      value
    end
  end
end
