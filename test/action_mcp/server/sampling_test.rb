# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class SamplingTest < ActiveSupport::TestCase
      test "sends a protocol-correct sampling request" do
        session = sampling_session(sampling: {})
        transport = TransportHandler.new(session, messaging_mode: :return)

        result = transport.send_sampling_create_message("sample-1", basic_params)

        assert_instance_of JSON_RPC::Request, result
        assert_equal "sample-1", result.id
        assert_equal "sampling/createMessage", result.method
        assert_equal basic_params, result.params
      end

      test "requires the sampling client capability" do
        transport = TransportHandler.new(sampling_session({}), messaging_mode: :return)

        assert_raises(UnsupportedSamplingError) do
          transport.send_sampling_create_message("sample-1", basic_params)
        end
      end

      test "requires tool support for tools and tool choice" do
        transport = TransportHandler.new(sampling_session(sampling: {}), messaging_mode: :return)
        params = basic_params.merge(
          tools: [ { name: "lookup", inputSchema: { type: "object" } } ],
          toolChoice: { mode: "auto" }
        )

        assert_raises(UnsupportedSamplingError) do
          transport.send_sampling_create_message("sample-1", params)
        end

        supported = TransportHandler.new(
          sampling_session(sampling: { tools: {} }),
          messaging_mode: :return
        )
        assert_equal "sampling/createMessage",
                     supported.send_sampling_create_message("sample-2", params).method
      end

      test "requires context support for cross-request context" do
        transport = TransportHandler.new(sampling_session(sampling: {}), messaging_mode: :return)

        assert_raises(UnsupportedSamplingError) do
          transport.send_sampling_create_message(
            "sample-1",
            basic_params.merge(includeContext: "thisServer")
          )
        end
      end

      test "requires task support for task-augmented sampling" do
        params = basic_params.merge(task: { ttl: 60_000 })
        transport = TransportHandler.new(sampling_session(sampling: {}), messaging_mode: :return)

        assert_raises(UnsupportedSamplingError) do
          transport.send_sampling_create_message("sample-1", params)
        end

        capabilities = {
          sampling: {},
          tasks: { requests: { sampling: { createMessage: {} } } }
        }
        supported = TransportHandler.new(sampling_session(capabilities), messaging_mode: :return)
        assert_equal params, supported.send_sampling_create_message("sample-2", params).params
      end

      test "rejects malformed request params before writing" do
        session = sampling_session(sampling: {})
        transport = TransportHandler.new(session, messaging_mode: :return)

        assert_raises(ArgumentError) do
          transport.send_sampling_create_message(
            "sample-1",
            messages: [ { role: "system", content: { type: "text", text: "bad" } } ],
            maxTokens: 100
          )
        end
        assert_nil session.written
      end

      private

      def basic_params
        {
          messages: [ { role: "user", content: { type: "text", text: "Review this" } } ],
          maxTokens: 100
        }
      end

      def sampling_session(client_capabilities)
        Struct.new(:client_capabilities, :written) do
          def write(message)
            self.written = message
          end
        end.new(client_capabilities, nil)
      end
    end
  end
end
