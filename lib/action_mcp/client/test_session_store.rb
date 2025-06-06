# frozen_string_literal: true

module ActionMCP
  module Client
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
  end
end
