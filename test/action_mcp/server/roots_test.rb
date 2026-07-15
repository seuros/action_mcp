# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class RootsTest < ActiveSupport::TestCase
      test "sends roots/list as a server-to-client request" do
        session = roots_session(roots: { listChanged: true })
        transport = TransportHandler.new(session, messaging_mode: :return)

        result = transport.send_roots_list("roots-1")

        assert_instance_of JSON_RPC::Request, result
        assert_equal "roots-1", result.id
        assert_equal "roots/list", result.method
        assert_nil result.params
      end

      test "generates a request id when one is omitted" do
        transport = TransportHandler.new(roots_session(roots: {}), messaging_mode: :return)

        assert transport.send_roots_list.id.present?
      end

      test "rejects roots/list when the client did not negotiate roots" do
        session = roots_session({})
        transport = TransportHandler.new(session, messaging_mode: :return)

        assert_raises(UnsupportedRootsError) { transport.send_roots_list("roots-1") }
        assert_nil session.written
      end

      test "refreshes roots only when list changes were negotiated" do
        unsupported_session = roots_session(roots: { listChanged: false })
        unsupported = TransportHandler.new(unsupported_session, messaging_mode: :return)

        assert_nil unsupported.refresh_roots_list
        assert_nil unsupported_session.written

        supported = TransportHandler.new(
          roots_session(roots: { listChanged: true }),
          messaging_mode: :return
        )
        assert_equal "roots/list", supported.refresh_roots_list.method
      end

      private

      def roots_session(client_capabilities)
        Struct.new(:client_capabilities, :written) do
          def write(message)
            self.written = message
          end
        end.new(client_capabilities, nil)
      end
    end
  end
end
