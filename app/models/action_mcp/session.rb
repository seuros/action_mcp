# frozen_string_literal: true

# == Schema Information
#
# Table name: action_mcp_sessions
#
#  id                                                  :string           not null, primary key
#  client_capabilities(The capabilities of the client) :jsonb
#  client_info(The information about the client)       :jsonb
#  ended_at(The time the session ended)                :datetime
#  initialized                                         :boolean          default(FALSE), not null
#  messages_count                                      :integer          default(0), not null
#  protocol_version                                    :string
#  role(The role of the session)                       :string           default("server"), not null
#  server_capabilities(The capabilities of the server) :jsonb
#  server_info(The information about the server)       :jsonb
#  status                                              :string           default("pre_initialize"), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#
module ActionMCP
  ##
  # Represents an MCP session, which is a connection between a client and a server.
  # Its role is to manage the communication channel and store information about the session,
  # such as client and server capabilities, protocol version, and session status.
  # It also manages the association with messages and subscriptions related to the session.
  class Session < ApplicationRecord
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
      subscriptions.delete_all # delete all subscriptions
    end

    def write(data)
      if data.is_a?(JsonRpc::Request) || data.is_a?(JsonRpc::Response) || data.is_a?(JsonRpc::Notification)
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
        protocolVersion: PROTOCOL_VERSION,
        serverInfo: server_info,
        capabilities: server_capabilities
      }
    end

    def initialize!
      # update the session initialized to true if client_capabilities are present
      return unless client_capabilities.present?

      update!(initialized: true,
              status: "initialized")
    end

    def message_flow
      messages.without_pings.order(created_at: :asc).map do |message|
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

    def resource_subscribe(uri)
      subscriptions.find_or_create_by(uri: uri)
    end

    def resource_unsubscribe(uri)
      subscriptions.find_by(uri: uri)&.destroy
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
