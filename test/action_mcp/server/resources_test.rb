# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class ResourcesTest < ActiveSupport::TestCase
      class TestSession
        attr_reader :registered_resource_templates, :subscriptions

        def initialize
          @registered_resource_templates = []
          @subscriptions = []
        end

        def consent_granted_for?(_key)
          true
        end

        def resource_subscribe(uri)
          @subscriptions << uri unless @subscriptions.include?(uri)
        end

        def resource_unsubscribe(uri)
          @subscriptions.delete(uri)
        end
      end

      class TestTransport
        include Resources

        attr_reader :responses, :errors

        def initialize
          @session = TestSession.new
          @responses = []
          @errors = []
        end

        def session
          @session
        end

        def send_jsonrpc_response(id, result: nil, error: nil)
          @responses << { id: id, result: result, error: error }
        end

        def send_jsonrpc_error(id, symbol, message, data = nil)
          @errors << { id: id, symbol: symbol, message: message, data: data }
        end
      end

      test "send_resource_read returns not found when template does not accept URI" do
        transport = TestTransport.new
        uri = "demo://resource/1"
        template = Class.new do
          def self.name = "UnreadableTemplate"
          def self.readable_uri?(_uri) = false
        end
        transport.session.registered_resource_templates << template

        resolver = ->(_uri, templates:) { templates.include?(template) ? template : nil }
        ActionMCP::ResourceTemplatesRegistry.stub(:find_template_for_uri, resolver) do
          transport.send_resource_read(100, { "uri" => uri })
        end

        response = transport.responses.last
        assert_nil response[:result]
        assert_equal(-32_002, response[:error][:code])
        assert_equal "Resource not found", response[:error][:message]
        assert_equal({ uri: uri }, response[:error][:data])
      end

      test "send_resource_read passes _meta through on contents" do
        transport = TestTransport.new
        uri = "meta-echo://item/42"
        template = ActionMCP::ResourceTemplatesRegistry.find_template_for_uri(uri)
        transport.session.registered_resource_templates << template
        transport.send_resource_read(101, { "uri" => uri })

        response = transport.responses.last
        assert_nil response[:error]
        content = response[:result][:contents].first
        assert_equal({ ui: { prefersBorder: true } }, content[:_meta])
      end

      test "send_resource_read does not resolve templates outside the session" do
        transport = TestTransport.new
        uri = "meta-echo://item/42"

        assert ActionMCP::ResourceTemplatesRegistry.find_template_for_uri(uri)
        transport.send_resource_read(102, { "uri" => uri })

        response = transport.responses.sole
        assert_nil response[:result]
        assert_equal(-32_002, response[:error][:code])
      end

      test "subscribe and unsubscribe persist session state and return empty results" do
        transport = TestTransport.new
        uri = "meta-echo://item/42"
        template = ActionMCP::ResourceTemplatesRegistry.find_template_for_uri(uri)
        transport.session.registered_resource_templates << template

        transport.send_resource_subscribe(103, uri)

        assert_equal({}, transport.responses.last[:result])
        assert_includes transport.session.subscriptions, uri

        transport.send_resource_unsubscribe(104, uri)

        assert_equal({}, transport.responses.last[:result])
        refute_includes transport.session.subscriptions, uri
      end

      test "normalized resource content omits a nil mime type" do
        transport = TestTransport.new
        content = ActionMCP::Content::Resource.new("urn:example:item", nil, text: "body")

        normalized = transport.send(:normalize_read_content, content, content.uri)

        assert_equal({ uri: "urn:example:item", text: "body" }, normalized)
        refute normalized.key?(:mimeType)
      end
    end
  end
end
