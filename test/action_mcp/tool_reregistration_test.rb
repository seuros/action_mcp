# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ToolReregistrationTest < ActiveSupport::TestCase
    setup do
      @original_tools = ToolsRegistry.items.dup
      ToolsRegistry.clear!
    end

    teardown do
      ToolsRegistry.clear!
      @original_tools.each do |name, klass|
        ToolsRegistry.items[name] = klass
      end
    end

    test "tool with explicit tool_name registers under custom name not default" do
      ToolsRegistry.register(Spaceship::WeatherTool)

      # Should be registered under explicit name
      assert_includes ToolsRegistry.tools.keys, "spaceship_weather"
      # Should NOT be registered under default name
      refute_includes ToolsRegistry.tools.keys, "spaceship__weather"
    end

    test "tool without explicit tool_name uses default name" do
      ToolsRegistry.register(Mars::WeatherTool)

      assert_includes ToolsRegistry.tools.keys, "mars__weather"
    end

    test "re-registration is idempotent" do
      ToolsRegistry.register(Spaceship::WeatherTool)
      initial_size = ToolsRegistry.tools.size

      # Calling tool_name again with same value should not duplicate
      Spaceship::WeatherTool.tool_name("spaceship_weather")

      assert_equal initial_size, ToolsRegistry.tools.size
      assert_equal 1, ToolsRegistry.tools.values.count { |k| k == Spaceship::WeatherTool }
    end

    test "_registered_name is set after registration" do
      ToolsRegistry.register(Spaceship::WeatherTool)

      assert_equal "spaceship_weather", Spaceship::WeatherTool._registered_name
    end

    test "re_register removes old entry and adds new entry" do
      # Manually register under a wrong name to simulate the timing issue
      ToolsRegistry.items["wrong_name"] = Spaceship::WeatherTool
      Spaceship::WeatherTool._registered_name = "wrong_name"

      # Now call re_register
      ToolsRegistry.re_register(Spaceship::WeatherTool, "wrong_name")

      # Old entry should be gone
      refute_includes ToolsRegistry.tools.keys, "wrong_name"
      # New entry should exist
      assert_includes ToolsRegistry.tools.keys, "spaceship_weather"
      assert_equal "spaceship_weather", Spaceship::WeatherTool._registered_name
    end

    test "abstract tools are not re-registered" do
      # ApplicationMCPTool is abstract
      initial_size = ToolsRegistry.tools.size

      ToolsRegistry.re_register(ApplicationMCPTool, "some_name")

      assert_equal initial_size, ToolsRegistry.tools.size
    end
  end
end
