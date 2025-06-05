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
        # Return the reloaded session to get the actual saved values
        load_session(session_id)
      end
    end

    # Volatile session store for development (data lost on restart)
    class VolatileSessionStore
      include SessionStore

      def initialize
        @sessions = Concurrent::Hash.new
      end

      def load_session(session_id)
        @sessions[session_id]
      end

      def save_session(session_id, session_data)
        @sessions[session_id] = session_data.dup
      end

      def delete_session(session_id)
        @sessions.delete(session_id)
      end

      def session_exists?(session_id)
        @sessions.key?(session_id)
      end

      def clear_all
        @sessions.clear
      end

      def session_count
        @sessions.size
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

    # Test session store that tracks all operations for assertions
    class TestSessionStore < VolatileSessionStore
      attr_reader :operations, :saved_sessions, :loaded_sessions,
                  :deleted_sessions, :updated_sessions

      def initialize
        super
        @operations = Concurrent::Array.new
        @saved_sessions = Concurrent::Array.new
        @loaded_sessions = Concurrent::Array.new
        @deleted_sessions = Concurrent::Array.new
        @updated_sessions = Concurrent::Array.new
      end

      def load_session(session_id)
        session = super
        @operations << { type: :load, session_id: session_id, found: !session.nil? }
        @loaded_sessions << session_id if session
        session
      end

      def save_session(session_id, session_data)
        super
        @operations << { type: :save, session_id: session_id, data: session_data }
        @saved_sessions << session_id
      end

      def delete_session(session_id)
        result = super
        @operations << { type: :delete, session_id: session_id }
        @deleted_sessions << session_id
        result
      end

      def update_session(session_id, attributes)
        result = super
        @operations << { type: :update, session_id: session_id, attributes: attributes }
        @updated_sessions << session_id if result
        result
      end

      # Test helper methods
      def session_saved?(session_id)
        @saved_sessions.include?(session_id)
      end

      def session_loaded?(session_id)
        @loaded_sessions.include?(session_id)
      end

      def session_deleted?(session_id)
        @deleted_sessions.include?(session_id)
      end

      def session_updated?(session_id)
        @updated_sessions.include?(session_id)
      end

      def operation_count(type = nil)
        if type
          @operations.count { |op| op[:type] == type }
        else
          @operations.size
        end
      end

      def last_saved_data(session_id)
        @operations.reverse.find { |op| op[:type] == :save && op[:session_id] == session_id }&.dig(:data)
      end

      def reset_tracking!
        @operations.clear
        @saved_sessions.clear
        @loaded_sessions.clear
        @deleted_sessions.clear
        @updated_sessions.clear
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
