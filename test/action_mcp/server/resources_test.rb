# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class ResourcesTest < ActiveSupport::TestCase
      class TestSession
        attr_reader :registered_resource_templates

        def initialize
          @registered_resource_templates = []
        end

        def consent_granted_for?(_key)
          true
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

        ActionMCP::ResourceTemplatesRegistry.stub(:find_template_for_uri, template) do
          transport.send_resource_read(100, { "uri" => uri })
        end

        response = transport.responses.last
        assert_nil response[:result]
        assert_equal(-32_002, response[:error][:code])
        assert_equal "Resource not found", response[:error][:message]
        assert_equal({ uri: uri }, response[:error][:data])
      end
    end
  end
end
