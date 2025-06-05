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

      # Client session store assertions
      def assert_client_session_saved(session_id, message = nil)
        assert client_session_store.session_saved?(session_id),
               message || "Expected client session #{session_id} to have been saved"
      end

      def assert_client_session_not_saved(session_id, message = nil)
        assert_not client_session_store.session_saved?(session_id),
                   message || "Expected client session #{session_id} not to have been saved"
      end

      def assert_client_session_loaded(session_id, message = nil)
        assert client_session_store.session_loaded?(session_id),
               message || "Expected client session #{session_id} to have been loaded"
      end

      def assert_client_session_not_loaded(session_id, message = nil)
        assert_not client_session_store.session_loaded?(session_id),
                   message || "Expected client session #{session_id} not to have been loaded"
      end

      def assert_client_session_updated(session_id, message = nil)
        assert client_session_store.session_updated?(session_id),
               message || "Expected client session #{session_id} to have been updated"
      end

      def assert_client_session_not_updated(session_id, message = nil)
        assert_not client_session_store.session_updated?(session_id),
                   message || "Expected client session #{session_id} not to have been updated"
      end

      def assert_client_session_deleted(session_id, message = nil)
        assert client_session_store.session_deleted?(session_id),
               message || "Expected client session #{session_id} to have been deleted"
      end

      def assert_client_session_not_deleted(session_id, message = nil)
        assert_not client_session_store.session_deleted?(session_id),
                   message || "Expected client session #{session_id} not to have been deleted"
      end

      def assert_client_session_operation_count(expected, type = nil, message = nil)
        actual = client_session_store.operation_count(type)
        type_desc = type ? " of type #{type}" : ""
        assert_equal expected, actual,
                     message || "Expected #{expected} client session operations#{type_desc}, got #{actual}"
      end

      def assert_client_session_data_includes(session_id, expected_data, message = nil)
        saved_data = client_session_store.last_saved_data(session_id)
        assert saved_data, "No saved data found for session #{session_id}"

        expected_data.each do |key, value|
          assert_equal value, saved_data[key],
                       message || "Expected session #{session_id} data to include #{key}: #{value}"
        end
      end

      private

      def server_session_store
        store = ActionMCP::Server.session_store
        raise "Server session store is not a TestSessionStore" unless store.is_a?(ActionMCP::Server::TestSessionStore)
        store
      end

      def client_session_store
        # This would need to be set by the test or could use a thread-local variable
        # For now, we'll assume it's available as an instance variable
        store = @client_session_store || Thread.current[:test_client_session_store]
        raise "Client session store not set. Set @client_session_store or Thread.current[:test_client_session_store]" unless store
        raise "Client session store is not a TestSessionStore" unless store.is_a?(ActionMCP::Client::TestSessionStore)
        store
      end
    end
  end
end
