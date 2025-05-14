# frozen_string_literal: true

require "test_helper"


module ActionMCP
  module Client
    class ToolboxTest < ActiveSupport::TestCase
      setup do
        @toolbox = Toolbox.new(load_fixture("toolbox"), nil)
      end

      test "initializes with tool data" do
        assert_equal 2, @toolbox.size
      end

      test "returns all tools" do
        tools = @toolbox.all
        assert_equal 2, tools.size
        assert_instance_of Toolbox::Tool, tools.first
      end

      test "finds a tool by name" do
        tool = @toolbox.find("calculate_sum")
        assert_equal "calculate_sum", tool.name
        assert_equal "Calculate the sum of two numbers", tool.description
      end

      test "returns nil when finding a nonexistent tool" do
        assert_nil @toolbox.find("nonexistent")
      end

      test "filters tools with a block" do
        calc_tools = @toolbox.filter { |t| t.name.include?("calculate") }
        assert_equal 1, calc_tools.size
        assert_equal "calculate_sum", calc_tools.first.name
      end

      test "returns all tool names" do
        assert_equal %w[weather_forecast calculate_sum], @toolbox.names
      end

      test "checks if toolbox contains a tool" do
        assert @toolbox.contains?("weather_forecast")
        refute @toolbox.contains?("nonexistent")
      end

      test "searches tools by keyword" do
        results = @toolbox.search("forecast")
        assert_equal 1, results.size
        assert_equal "weather_forecast", results.first.name
      end

      test "enumerates all tools" do
        names = []
        @toolbox.each { |tool| names << tool.name }
        assert_equal %w[weather_forecast calculate_sum], names
      end

      test "tool gets required properties" do
        tool = @toolbox.find("weather_forecast")
        required = tool.required_properties
        assert_equal 1, required.size
        assert_equal "location", required.first
      end

      test "tool gets properties" do
        tool = @toolbox.find("calculate_sum")
        props = tool.properties
        assert_equal 2, props.size
        assert props.key?("number1")
        assert props.key?("number2")
      end

      test "tool checks if property is required" do
        tool = @toolbox.find("calculate_sum")
        assert tool.requires?("number1")
        refute tool.requires?("nonexistent")
      end

      test "tool checks if property exists" do
        tool = @toolbox.find("weather_forecast")
        assert tool.has_property?("days")
        refute tool.has_property?("nonexistent")
      end

      test "tool gets property details" do
        tool = @toolbox.find("weather_forecast")
        prop = tool.property("location")
        assert_equal "string", prop["type"]
        assert_equal "City name or postal code", prop["description"]
      end

      test "tool generates hash representation" do
        tool = @toolbox.find("calculate_sum")
        hash = tool.to_h
        assert_equal "calculate_sum", hash["name"]
        assert_equal "Calculate the sum of two numbers", hash["description"]
        assert hash["inputSchema"].key?("properties")
        assert hash["annotations"].is_a?(Hash)
      end

      test "tool with annotations" do
        toolbox = Toolbox.new(load_fixture("toolbox_with_annotations"), nil)
        tool = toolbox.find("annotated_tool")
        assert_equal "Annotated Tool", tool.description
        assert_equal({ "safety" => "safe", "category" => "test" }, tool.annotations)
      end

      test "toolbox generates default hash representation with all tools" do
        hash = @toolbox.to_h
        assert_equal 2, hash["tools"].size
        assert_equal "weather_forecast", hash["tools"].first["name"]
        assert_equal "calculate_sum", hash["tools"].last["name"]
        assert hash["tools"].first["inputSchema"].key?("properties")
      end

      test "toolbox generates Claude format hash representation" do
        hash = @toolbox.to_h(:claude)
        assert_equal 2, hash["tools"].size

        tool = hash["tools"].first
        assert_equal "weather_forecast", tool["name"]
        assert_equal "Get detailed weather forecast for a location with progressive updates", tool["description"]
        assert tool["input_schema"]
        assert tool["input_schema"]["properties"]
        assert_equal "string", tool["input_schema"]["properties"]["location"]["type"]
      end

      test "toolbox generates OpenAI format hash representation" do
        hash = @toolbox.to_h(:openai)
        assert_equal 2, hash["tools"].size

        tool = hash["tools"].first
        assert_equal "function", tool["type"]
        assert tool["function"]
        assert_equal "weather_forecast", tool["function"]["name"]
        assert_equal "Get detailed weather forecast for a location with progressive updates",
                     tool["function"]["description"]
        assert tool["function"]["parameters"]
        assert tool["function"]["parameters"]["properties"]
        assert_equal "string", tool["function"]["parameters"]["properties"]["location"]["type"]
      end

      test "tool generates Claude format hash representation" do
        tool = @toolbox.find("calculate_sum")
        hash = tool.to_claude_h

        assert_equal "calculate_sum", hash["name"]
        assert_equal "Calculate the sum of two numbers", hash["description"]
        assert hash["input_schema"]
      end

      test "tool generates OpenAI format hash representation" do
        tool = @toolbox.find("calculate_sum")
        hash = tool.to_openai_h

        assert_equal "function", hash["type"]
        assert hash["function"]
        assert_equal "calculate_sum", hash["function"]["name"]
        assert_equal "Calculate the sum of two numbers", hash["function"]["description"]
        assert hash["function"]["parameters"]
      end
    end
  end
end
