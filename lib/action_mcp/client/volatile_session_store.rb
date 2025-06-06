# frozen_string_literal: true

module ActionMCP
  module Client
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
  end
end
