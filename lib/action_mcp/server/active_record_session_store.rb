# frozen_string_literal: true

module ActionMCP
  module Server
    # ActiveRecord-backed session store (default for production)
    class ActiveRecordSessionStore
      include SessionStore

      def create_session(session_id = nil, attributes = {})
        session = ActionMCP::Session.new(attributes)
        session.id = session_id if session_id
        session.save!
        session
      end

      def load_session(session_id)
        ActionMCP::Session.find_by(id: session_id)
      end

      def save_session(session)
        session.save! if session.is_a?(ActionMCP::Session)
      end

      def delete_session(session_id)
        ActionMCP::Session.find_by(id: session_id)&.destroy
      end

      def session_exists?(session_id)
        ActionMCP::Session.exists?(id: session_id)
      end

      def find_sessions(criteria = {})
        scope = ActionMCP::Session.all

        scope = scope.where(status: criteria[:status]) if criteria[:status]
        scope = scope.where(role: criteria[:role]) if criteria[:role]

        scope
      end

      def cleanup_expired_sessions(older_than: 24.hours.ago)
        ActionMCP::Session.where("updated_at < ?", older_than).destroy_all
      end
    end
  end
end
