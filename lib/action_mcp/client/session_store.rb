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
  end
end
