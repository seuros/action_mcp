# frozen_string_literal: true

module ActionMCP
  module Client
    # ActiveRecord-backed session store for production
    class ActiveRecordSessionStore
      include SessionStore

      def load_session(session_id)
        session = ActionMCP::Session.find_by(id: session_id)
        return nil unless session

        {
          id: session.id,
          protocol_version: session.protocol_version,
          client_info: session.client_info,
          client_capabilities: session.client_capabilities,
          server_info: session.server_info,
          server_capabilities: session.server_capabilities,
          created_at: session.created_at,
          updated_at: session.updated_at
        }
      end

      def save_session(session_id, session_data)
        session = ActionMCP::Session.find_or_initialize_by(id: session_id)

        # Only assign attributes that exist in the database
        attributes = {}
        attributes[:protocol_version] = session_data[:protocol_version] if session_data.key?(:protocol_version)
        attributes[:client_info] = session_data[:client_info] if session_data.key?(:client_info)
        attributes[:client_capabilities] = session_data[:client_capabilities] if session_data.key?(:client_capabilities)
        attributes[:server_info] = session_data[:server_info] if session_data.key?(:server_info)
        attributes[:server_capabilities] = session_data[:server_capabilities] if session_data.key?(:server_capabilities)

        # Store any extra data in a jsonb column if available
        # For now, we'll skip last_event_id and session_data as they don't exist in the DB

        session.assign_attributes(attributes)
        session.save!
        session_data
      end

      def delete_session(session_id)
        ActionMCP::Session.find_by(id: session_id)&.destroy
      end

      def session_exists?(session_id)
        ActionMCP::Session.exists?(id: session_id)
      end

      def cleanup_expired_sessions(older_than: 24.hours.ago)
        ActionMCP::Session.where("updated_at < ?", older_than).delete_all
      end
    end
  end
end
