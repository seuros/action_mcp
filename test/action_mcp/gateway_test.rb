# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class GatewayTest < ActiveSupport::TestCase
    class MockRequest
      def headers
        {}
      end

      def env
        {}
      end
    end

    test "Gateway initializes with request" do
      request = MockRequest.new
      gateway = TestGateway.new(request)
      assert_equal request, gateway.instance_variable_get(:@request)
    end

    test "Gateway.identified_by sets identifier classes" do
      assert_equal [ TestIdentifier ], TestGateway.identifier_classes
    end

    test "Gateway#call authenticates and assigns identities" do
      with_authentication_config([ "test" ]) do
        request = MockRequest.new
        gateway = TestGateway.new(request)

        result = gateway.call
        assert_equal gateway, result

        # Should have assigned the user identity from TestIdentifier
        assert_respond_to gateway, :user
        assert_equal "test_user", gateway.user
      end
    end

    test "Gateway raises UnauthorizedError when authentication fails" do
      class FailingIdentifier < ActionMCP::GatewayIdentifier
        identifier :user
        authenticates :failing

        def resolve
          raise Unauthorized, "Test failure"
        end
      end

      class FailingGateway < ActionMCP::Gateway
        identified_by FailingIdentifier
      end

      with_authentication_config([ "failing" ]) do
        request = MockRequest.new
        gateway = FailingGateway.new(request)

        assert_raises ActionMCP::UnauthorizedError do
          gateway.call
        end
      end
    end

    test "Gateway filters identifiers based on authentication_methods config" do
      with_authentication_config([ "api_key" ]) do
        request = MockRequest.new
        gateway = TestGateway.new(request)

        # TestIdentifier authenticates "test", but config only allows "api_key"
        # So no identifiers should be active, causing authentication failure
        assert_raises ActionMCP::UnauthorizedError do
          gateway.call
        end
      end
    end
  end
end
