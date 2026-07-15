# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class CompletionsTest < ActiveSupport::TestCase
      PromptDefinition = Class.new do
        def self.prompt_name = "review"

        def self.arguments
          [ { name: "language", enum: %w[python pytorch ruby] } ]
        end
      end

      ResourceDefinition = Class.new do
        def self.uri_template = "repo://{owner}/{name}"

        def self.parameters
          { owner: { enum: %w[openai rails ruby] } }
        end
      end

      TestSession = Struct.new(
        :server_capabilities,
        :registered_prompts,
        :registered_resource_templates,
        keyword_init: true
      )

      class TestTransport
        include Completions

        attr_reader :session, :responses, :errors

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
        @session = TestSession.new(
          server_capabilities: { completions: {} },
          registered_prompts: [ PromptDefinition ],
          registered_resource_templates: [ ResourceDefinition ]
        )
        @transport = TestTransport.new(@session)
      end

      test "completes a registered prompt enum" do
        @transport.send_completion_complete("complete-1", {
          "ref" => { "type" => "ref/prompt", "name" => "review" },
          "argument" => { "name" => "language", "value" => "py" }
        })

        completion = @transport.responses.sole[:result][:completion]
        assert_equal %w[python pytorch], completion[:values]
        assert_equal 2, completion[:total]
        assert_equal false, completion[:hasMore]
      end

      test "completes a registered resource template enum" do
        @transport.send_completion_complete("complete-2", {
          "ref" => { "type" => "ref/resource", "uri" => "repo://{owner}/{name}" },
          "argument" => { "name" => "owner", "value" => "r" }
        })

        assert_equal %w[rails ruby], @transport.responses.sole[:result][:completion][:values]
      end

      test "rejects missing required request fields" do
        @transport.send_completion_complete("complete-3", {})

        assert_equal :invalid_params, @transport.errors.sole[:symbol]
      end

      test "does not complete references outside the session" do
        @transport.send_completion_complete("complete-4", {
          "ref" => { "type" => "ref/prompt", "name" => "hidden" },
          "argument" => { "name" => "language", "value" => "" }
        })

        assert_equal :invalid_params, @transport.errors.sole[:symbol]
      end

      test "rejects requests when completion was not advertised" do
        @session.server_capabilities = {}

        @transport.send_completion_complete("complete-5", {
          "ref" => { "type" => "ref/prompt", "name" => "review" },
          "argument" => { "name" => "language", "value" => "" }
        })

        assert_equal :method_not_found, @transport.errors.sole[:symbol]
      end
    end
  end
end
