# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class GatewayProfileTest < ActiveSupport::TestCase
    test "gateway has apply_profile_from_authentication hook method" do
      # Verify that the Gateway base class has the hook method
      assert_respond_to ActionMCP::Gateway, :new

      # Create a gateway instance and verify the hook method exists
      request = Struct.new(:headers, :env).new({}, {})
      gateway = ActionMCP::Gateway.new(request)
      assert gateway.respond_to?(:apply_profile_from_authentication, true)
    end

    test "apply_profile_from_authentication can be overridden in subclasses" do
      # Create a test gateway that overrides the hook
      test_gateway_class = Class.new(ActionMCP::Gateway) do
        attr_reader :profile_applied

        def apply_profile_from_authentication(identities)
          @profile_applied = true
        end
      end

      request = Struct.new(:headers, :env).new({}, {})
      gateway = test_gateway_class.new(request)

      # Call the method and verify it works
      gateway.send(:apply_profile_from_authentication, {})
      assert gateway.profile_applied
    end

    test "gateway documentation includes profile switching example" do
      # Verify the Gateway class has documentation about profile switching
      gateway_code = File.read(File.join(ActionMCP::Engine.root, "lib/action_mcp/gateway.rb"))
      assert_includes gateway_code, "apply_profile_from_authentication"
      assert_includes gateway_code, "user&.admin?"
      assert_includes gateway_code, "use_profile"
    end
  end
end
