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
        include TransportMocks::RecordingTransport

        attr_reader :session

        def initialize
          @session = TestSession.new
        end
      end

      def meta_echo_transport
        TestTransport.new.tap do |transport|
          transport.session.registered_resource_templates <<
            ActionMCP::ResourceTemplatesRegistry.find_template_for_uri("meta-echo://item/42")
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
        transport = meta_echo_transport
        transport.send_resource_read(101, { "uri" => "meta-echo://item/42" })

        response = transport.responses.last
        assert_nil response[:error]
        content = response[:result][:contents].first
        assert_equal({ ui: { prefersBorder: true } }, content[:_meta])
        assert_equal({}, JSON.parse(content[:text]))
      end

      test "send_resource_read exposes the request _meta to the template" do
        transport = meta_echo_transport

        transport.send_resource_read(105, { "uri" => "meta-echo://item/42", "_meta" => { "example.com/trace" => "abc" } })

        content = transport.responses.sole[:result][:contents].first
        assert_equal({ "example.com/trace" => "abc" }, JSON.parse(content[:text]))
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
