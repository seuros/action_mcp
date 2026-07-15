# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class PromptsTest < ActiveSupport::TestCase
      include TransportMocks

      PromptDefinition = Class.new(ActionMCP::Prompt) do
        prompt_name "greeting"
        argument :name, required: true

        def perform
          render(text: "Hello, #{name}", role: "user")
        end
      end

      TestSession = Struct.new(:registered_prompts, keyword_init: true)

      class TestTransport
        include Prompts

        attr_reader :responses, :errors, :session

        def initialize(session)
          @session = session
          @responses = []
          @errors = []
        end

        def send_jsonrpc_response(id, result: nil, error: nil)
          @responses << { id: id, result: result, error: error }
        end

        def send_jsonrpc_error(id, symbol, message, data = nil)
          @errors << { id: id, symbol: symbol, message: message, data: data }
        end
      end

      setup do
        @transport = TestTransport.new(TestSession.new(registered_prompts: [ PromptDefinition ]))
      end

      test "serializes prompt validation errors as JSON-RPC errors" do
        @transport.send_prompts_get("prompt-1", "greeting", {})

        error = @transport.responses.sole[:error]
        assert_equal(-32_602, error[:code])
        assert_equal "Invalid input", error[:message]
      end

      test "unknown prompts use invalid params" do
        @transport.send_prompts_get("prompt-2", "hidden", {})

        assert_equal :invalid_params, @transport.errors.sole[:symbol]
      end

      test "serializes successful prompt results as hashes" do
        @transport.send_prompts_get("prompt-3", "greeting", { "name" => "Ada" })

        result = @transport.responses.sole[:result]
        assert_instance_of Hash, result
        assert_equal "Hello, Ada", result[:messages].sole[:content][:text]
      end

      test "rejects non-string prompt argument values" do
        session = DummySession.new
        session.define_singleton_method(:read) { |_request = nil| }
        transport = TransportHandler.new(session, messaging_mode: :return)
        handler = JsonRpcHandler.new(transport)
        request = JSON_RPC::Request.new(
          id: "prompt-4",
          method: "prompts/get",
          params: { "name" => "greeting", "arguments" => { "name" => 42 } }
        )

        response = handler.call(request)

        assert_equal(-32_602, response.error[:code])
        assert_equal "Prompt argument values must be strings", response.error[:message]
      end
    end
  end
end
