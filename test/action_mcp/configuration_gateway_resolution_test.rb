# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ConfigurationGatewayResolutionTest < ActiveSupport::TestCase
    test "gateway_class resolves correctly when configured" do
      # The test dummy app has gateway_class: "ApplicationGateway" in config/mcp.yml
      config = ActionMCP.configuration
      gateway_class = config.gateway_class

      # Should resolve to ApplicationGateway since it's configured and loaded
      assert gateway_class.is_a?(Class)
      assert gateway_class < ActionMCP::Gateway
    end

    test "gateway_class respects explicit gateway_class_name from config" do
      # If gateway_class_name is explicitly set from config, use that over fallback
      config = ActionMCP.configuration

      # Manually set gateway_class_name (simulating what extract_top_level_settings does)
      original_name = config.instance_variable_get(:@gateway_class_name)
      config.instance_variable_set(:@gateway_class_name, "ActionMCP::Gateway")

      assert_equal ActionMCP::Gateway, config.gateway_class

      # Restore original for other tests
      config.instance_variable_set(:@gateway_class_name, original_name)
    end

    test "gateway_class resolves lazily to ApplicationGateway if not explicitly set" do
      # Create a fresh configuration without an explicit gateway_class_name
      fresh_config = ActionMCP::Configuration.new

      # Don't set gateway_class_name (or set it to nil)
      fresh_config.instance_variable_set(:@gateway_class_name, nil)

      # The lazy resolver should find ApplicationGateway if it's defined
      gateway = fresh_config.gateway_class
      assert_not_nil gateway
      assert gateway.is_a?(Class)

      # Should either be ApplicationGateway or ActionMCP::Gateway
      assert [ ApplicationGateway, ActionMCP::Gateway ].include?(gateway)
    end

    test "gateway_class fallback to ActionMCP::Gateway works" do
      # Create a config with no gateway_class_name set
      fresh_config = ActionMCP::Configuration.new
      fresh_config.instance_variable_set(:@gateway_class_name, nil)

      # Call gateway_class - should not raise an error
      gateway = fresh_config.gateway_class
      assert_not_nil gateway
      assert gateway.is_a?(Class)
      assert gateway < ActionMCP::Gateway
    end
  end
end
