# frozen_string_literal: true

module ActionMCP
  module Server
    class BaseSessionStore
      include SessionStore

      def initialize
        @sessions = Concurrent::Hash.new
      end

      def create_session(session_id = nil, attributes = {})
        session_id ||= SecureRandom.hex(6)

        session_data = {
          id: session_id,
          status: "pre_initialize",
          initialized: false,
          role: "server",
          messages_count: 0,
          sse_event_counter: 0,
          created_at: Time.current,
          updated_at: Time.current
        }.merge(attributes)

        session = BaseSession.new(session_data, self)

        if session.role == "server"
          session.server_info = {
            name: ActionMCP.configuration.name,
            version: ActionMCP.configuration.version
          }
          session.server_capabilities = ActionMCP.configuration.capabilities

          session.tool_registry = ActionMCP.configuration.filtered_tools.map(&:name)
          session.prompt_registry = ActionMCP.configuration.filtered_prompts.map(&:name)
          session.resource_registry = ActionMCP.configuration.filtered_resources.map(&:name)
        end

        @sessions[session_id] = session
        session
      end

      def load_session(session_id)
        session = @sessions[session_id]
        if session
          session.instance_variable_set(:@new_record, false)
        end
        session
      end

      def save_session(session)
        @sessions[session.id] = session
      end

      def delete_session(session_id)
        @sessions.delete(session_id)
      end

      def session_exists?(session_id)
        @sessions.key?(session_id)
      end

      def find_sessions(criteria = {})
        sessions = @sessions.values

        sessions = sessions.select { |s| s.status == criteria[:status] } if criteria[:status]
        sessions = sessions.select { |s| s.role == criteria[:role] } if criteria[:role]

        sessions
      end

      def cleanup_expired_sessions(older_than: 24.hours.ago)
        expired_ids = @sessions.select { |_id, session| session.updated_at < older_than }.keys
        expired_ids.each { |id| @sessions.delete(id) }
        expired_ids.count
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
