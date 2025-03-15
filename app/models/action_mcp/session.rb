module ActionMCP
  class Session < ApplicationRecord
    attribute :id, :string, default: -> { SecureRandom.hex(6) }
    has_many :messages,
             class_name: "ActionMCP::Session::Message",
             foreign_key: "session_id",
             dependent: :destroy,
             inverse_of: :session

    scope :pre_initialize, -> { where(status: "pre_initialize") }
    scope :closed, -> { where(status: "closed") }
    scope :without_messages, -> { includes(:messages).where(action_mcp_session_messages: { id: nil }) }

    before_create :set_server_info
    before_create :set_server_capabilities

    validates :protocol_version, inclusion: { in: [ PROTOCOL_VERSION ] }, allow_nil: true

    def close!
      dummy_callback = ->(*) { } # this callback seem broken
      adapter.unsubscribe(session_key, dummy_callback)
      update!(status: "closed", ended_at: Time.zone.now)
    end

    def write(data)
      if data.is_a?(JsonRpc::Request) || data.is_a?(JsonRpc::Response) || data.is_a?(JsonRpc::Notification)
        data = data.to_json
      end
      if data.is_a?(Hash)
        data = MultiJson.dump(data)
      end

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
        protocolVersion: PROTOCOL_VERSION,
        serverInfo: server_info,
        capabilities: server_capabilities
      }
    end

    def initialize!
      # update the session initialized to true if client_capabilities are present
      update!(initialized: true,
              status: "initialized"
      ) if client_capabilities.present?
    end

    def message_flow
      messages.order(created_at: :asc).map do |message|
        {
          direction: message.direction,
          data: message.data,
          type: message.message_type
        }
      end
    end

    def send_ping!
      Session.logger.silence do
        write(JsonRpc::Request.new(id: Time.now.to_i, method: "ping"))
      end
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
  end
end
