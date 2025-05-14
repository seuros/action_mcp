# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    module JsonRpc
      class PingTest < ActiveSupport::TestCase
        include TransportMocks

        setup do
          @session = DummySession.new
          # Add a read method that accepts an argument
          def @session.read(request = nil)
            # Do nothing with the request in the test
          end
          @transport = TransportHandler.new(@session)
          @handler = JsonRpcHandler.new(@transport)
        end

        test "ping request is handled with empty response" do
          # Create a JSON-RPC ping request
          request = JSON_RPC::Request.new(
            id: "test-ping-1",
            method: "ping",
            params: nil
          )

          # Process the request
          @handler.call(request)

          # Check the JSON-RPC response in the transport
          response = @session.written
          assert_instance_of JSON_RPC::Response, response
          assert_equal "test-ping-1", response.id
          assert_equal({}, response.result)
          assert_nil response.error
        end

        test "ping method returns true from handle_common_methods" do
          result = @handler.send(:handle_common_methods, "ping", "test-id", nil)
          assert_equal true, result, "handle_common_methods should return true for 'ping'"
        end
      end
    end
  end
end
