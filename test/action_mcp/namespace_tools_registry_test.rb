# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class NamespaceToolsRegistryTest < ActiveSupport::TestCase
    setup do
      # Clear the registry before each test
      ToolsRegistry.clear!
    end

    test "registers multiple tools with same class name but different namespaces" do
      # The dummy app has Spaceship::WeatherTool and Station::WeatherTool
      # Both have the same class name "WeatherTool" but different namespaces
      ToolsRegistry.register(Spaceship::WeatherTool)
      ToolsRegistry.register(Station::WeatherTool)

      tools = ToolsRegistry.tools

      # Both tools should be registered with their explicit tool_names
      assert_includes tools, "spaceship_weather"
      assert_includes tools, "station_weather"

      assert_equal Spaceship::WeatherTool, tools["spaceship_weather"]
      assert_equal Station::WeatherTool, tools["station_weather"]
    end

    test "tool_call works with namespace tools" do
      ToolsRegistry.register(Spaceship::WeatherTool)
      ToolsRegistry.register(Station::WeatherTool)

      spaceship_response = ToolsRegistry.tool_call("spaceship_weather", { altitude: 400000 })
      station_response = ToolsRegistry.tool_call("station_weather", { location: "Kennedy Space Center" })

      assert_instance_of ToolResponse, spaceship_response
      assert_instance_of ToolResponse, station_response
      refute spaceship_response.error?
      refute station_response.error?
    end

    test "tools are not overwritten when using same class names from different modules" do
      ToolsRegistry.register(Spaceship::WeatherTool)
      initial_count = ToolsRegistry.tools.size

      ToolsRegistry.register(Station::WeatherTool)
      final_count = ToolsRegistry.tools.size

      # Registry size should increase by 1, not stay the same (this tests the bug)
      assert_equal initial_count + 1, final_count
    end

    test "tools with same class name in different modules must use explicit tool_name" do
      # When multiple modules have tools with the same class name,
      # they MUST use explicit tool_name to avoid collisions.
      # The default_tool_name will be the same for both, so explicit tool_name is required.
      spaceship = Spaceship::WeatherTool.new({})
      station = Station::WeatherTool.new({})

      # Both have the same default name (demodulized), which is why explicit tool_name is needed
      assert_equal "weather", spaceship.class.default_tool_name
      assert_equal "weather", station.class.default_tool_name

      # But their explicit tool_names are different to avoid collision
      assert_equal "spaceship_weather", spaceship.class.tool_name
      assert_equal "station_weather", station.class.tool_name
      assert_not_equal spaceship.class.tool_name, station.class.tool_name
    end
  end
end
