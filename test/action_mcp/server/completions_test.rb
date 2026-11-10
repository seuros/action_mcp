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
        include TransportMocks::RecordingTransport

        attr_reader :session

        def initialize(session)
          @session = session
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
        complete("complete-1", { "type" => "ref/prompt", "name" => "review" }, "language", "py")

        completion = @transport.responses.sole[:result][:completion]
        assert_equal %w[python pytorch], completion[:values]
        assert_equal 2, completion[:total]
        assert_equal false, completion[:hasMore]
      end

      test "completes a registered resource template enum" do
        complete("complete-2", { "type" => "ref/resource", "uri" => "repo://{owner}/{name}" }, "owner", "r")

        assert_equal %w[rails ruby], @transport.responses.sole[:result][:completion][:values]
      end

      test "rejects missing required request fields" do
        @transport.send_completion_complete("complete-3", {})

        assert_equal :invalid_params, @transport.errors.sole[:symbol]
      end

      test "does not complete references outside the session" do
        complete("complete-4", { "type" => "ref/prompt", "name" => "hidden" }, "language", "")

        assert_equal :invalid_params, @transport.errors.sole[:symbol]
      end

      test "rejects requests when completion was not advertised" do
        @session.server_capabilities = {}

        complete("complete-5", { "type" => "ref/prompt", "name" => "review" }, "language", "")

        assert_equal :method_not_found, @transport.errors.sole[:symbol]
      end

      private

      def complete(id, ref, argument_name, value)
        @transport.send_completion_complete(id, { "ref" => ref, "argument" => { "name" => argument_name, "value" => value } })
      end
    end
  end
end
