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
  end
end
