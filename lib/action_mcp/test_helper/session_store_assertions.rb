# frozen_string_literal: true

module ActionMCP
  module TestHelper
    module SessionStoreAssertions
      # Server session store assertions
      def assert_session_created(session_id, message = nil)
        assert server_session_store.session_created?(session_id),
               message || "Expected session #{session_id} to have been created"
      end

      def assert_session_not_created(session_id, message = nil)
        assert_not server_session_store.session_created?(session_id),
                   message || "Expected session #{session_id} not to have been created"
      end

      def assert_session_loaded(session_id, message = nil)
        assert server_session_store.session_loaded?(session_id),
               message || "Expected session #{session_id} to have been loaded"
      end

      def assert_session_not_loaded(session_id, message = nil)
        assert_not server_session_store.session_loaded?(session_id),
                   message || "Expected session #{session_id} not to have been loaded"
      end

      def assert_session_saved(session_id, message = nil)
        assert server_session_store.session_saved?(session_id),
               message || "Expected session #{session_id} to have been saved"
      end

      def assert_session_not_saved(session_id, message = nil)
        assert_not server_session_store.session_saved?(session_id),
                   message || "Expected session #{session_id} not to have been saved"
      end

      def assert_session_deleted(session_id, message = nil)
        assert server_session_store.session_deleted?(session_id),
               message || "Expected session #{session_id} to have been deleted"
      end

      def assert_session_not_deleted(session_id, message = nil)
        assert_not server_session_store.session_deleted?(session_id),
                   message || "Expected session #{session_id} not to have been deleted"
      end

      def assert_session_operation_count(expected, type = nil, message = nil)
        actual = server_session_store.operation_count(type)
        type_desc = type ? " of type #{type}" : ""
        assert_equal expected, actual,
                     message || "Expected #{expected} session operations#{type_desc}, got #{actual}"
      end

      private

      def server_session_store
        store = ActionMCP::Server.session_store
        raise "Server session store is not a TestSessionStore" unless store.is_a?(ActionMCP::Server::TestSessionStore)

        store
      end
    end
  end
end
