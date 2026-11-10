# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    module JsonRpc
      class CustomMethodsTest < ActiveSupport::TestCase
        include TransportMocks

        setup do
          @session = DummySession.new
          def @session.read(request = nil); end
          @transport = TransportHandler.new(@session, messaging_mode: :return)
          @handler = JsonRpcHandler.new(@transport)
        end

        teardown do
          ActionMCP.configuration.custom_methods.clear
        end

        test "registered method answers with the handler result" do
          received = nil
          ActionMCP.configuration.register_method("acme/toolsets/list") do |params, session|
            received = [ params, session ]
            { toolsets: [ "ops" ] }
          end

          response = call_method("acme/toolsets/list", { "scope" => "all" })

          assert_nil response.error
          assert_equal({ toolsets: [ "ops" ] }, response.result)
          assert_equal [ { "scope" => "all" }, @session ], received
        end

        test "accepts any callable" do
          ActionMCP.configuration.register_method("acme/echo", ->(params, _session) { params })

          assert_equal({ "x" => 1 }, call_method("acme/echo", { "x" => 1 }).result)
        end

        test "unknown method is method_not_found" do
          response = call_method("acme/missing")

          assert_equal(-32_601, response.error[:code])
        end

        test "JsonRpcError raised by the handler reaches the client unchanged" do
          ActionMCP.configuration.register_method("acme/strict") do |_params, _session|
            raise JSON_RPC::JsonRpcError.new(:invalid_params, message: "scope is required")
          end

          response = call_method("acme/strict")

          assert_equal(-32_602, response.error[:code])
          assert_equal "scope is required", response.error[:message]
        end

        test "other exceptions become internal_error and reach Rails.error" do
          ActionMCP.configuration.register_method("acme/boom") { |_params, _session| raise "kaboom" }

          reported = []
          subscriber = Object.new
          subscriber.define_singleton_method(:report) { |error, **| reported << error }
          Rails.error.subscribe(subscriber)

          response = call_method("acme/boom")

          assert_equal(-32_603, response.error[:code])
          assert_equal [ "kaboom" ], reported.map(&:message)
        ensure
          Rails.error.unsubscribe(subscriber)
        end

        test "core MCP namespaces cannot be registered" do
          %w[tools/list prompts/custom notifications/acme ping/x initialize/x].each do |name|
            assert_raises(ArgumentError, name) { ActionMCP.configuration.register_method(name) { {} } }
          end
        end

        test "names must be vendor-prefixed" do
          %w[toolsets acme/ /acme acme/list/].each do |name|
            assert_raises(ArgumentError, name) { ActionMCP.configuration.register_method(name) { {} } }
          end
        end

        test "registration requires a handler" do
          assert_raises(ArgumentError) { ActionMCP.configuration.register_method("acme/nothing") }
        end

        private

        def call_method(name, params = nil)
          @handler.call(JSON_RPC::Request.new(id: "req-1", method: name, params: params))
        end
      end
    end
  end
end
