# frozen_string_literal: true

module ActionMCP
  module Client
    # Abstract interface for session storage
    module SessionStore
      # Load session data by ID
      def load_session(session_id)
        raise NotImplementedError, "#{self.class} must implement #load_session"
      end

      # Save session data
      def save_session(session_id, session_data)
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

      # Update specific session attributes
      def update_session(session_id, attributes)
        session_data = load_session(session_id)
        return nil unless session_data

        session_data.merge!(attributes)
        save_session(session_id, session_data)
        session_data
      end
    end

    # In-memory session store for development/testing
    class MemorySessionStore
      include SessionStore

      def initialize
        @sessions = {}
        @mutex = Mutex.new
      end

      def load_session(session_id)
        @mutex.synchronize { @sessions[session_id] }
      end

      def save_session(session_id, session_data)
        @mutex.synchronize { @sessions[session_id] = session_data.dup }
      end

      def delete_session(session_id)
        @mutex.synchronize { @sessions.delete(session_id) }
      end

      def session_exists?(session_id)
        @mutex.synchronize { @sessions.key?(session_id) }
      end

      def clear_all
        @mutex.synchronize { @sessions.clear }
      end

      def session_count
        @mutex.synchronize { @sessions.size }
      end
    end

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
          last_event_id: session.last_event_id,
          session_data: session.session_data || {},
          created_at: session.created_at,
          updated_at: session.updated_at
        }
      end

      def save_session(session_id, session_data)
        session = ActionMCP::Session.find_or_initialize_by(id: session_id)

        session.assign_attributes(
          protocol_version: session_data[:protocol_version],
          client_info: session_data[:client_info],
          client_capabilities: session_data[:client_capabilities],
          server_info: session_data[:server_info],
          server_capabilities: session_data[:server_capabilities],
          last_event_id: session_data[:last_event_id],
          session_data: session_data[:session_data] || {}
        )

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

    # Factory for creating session stores
    class SessionStoreFactory
      def self.create(type = nil, **options)
        type ||= Rails.env.production? ? :active_record : :memory

        case type.to_sym
        when :memory
          MemorySessionStore.new
        when :active_record
          ActiveRecordSessionStore.new
        else
          raise ArgumentError, "Unknown session store type: #{type}"
        end
      end
    end
  end
end
