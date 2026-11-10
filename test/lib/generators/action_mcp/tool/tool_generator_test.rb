# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/action_mcp/tool/tool_generator"

class ToolGeneratorTest < Rails::Generators::TestCase
  tests ActionMCP::Generators::ToolGenerator
  include GeneratorTestDestination

  def generated_tool_path(name)
    generated_component_path(name, "tool", "tools")
  end


  test "generator creates tool file with correct class name" do
    run_generator %w[MyCustom]
    assert_file generated_tool_path("my_custom"), /class MyCustomTool < ApplicationMCPTool/
  end

  test "generator appends Tool to class name if not present" do
    run_generator %w[Another]
    assert_file generated_tool_path("another"), /class AnotherTool < ApplicationMCPTool/
  end

  test "generator does not double Tool in class name" do
    run_generator %w[AlreadyTool]
    assert_file generated_tool_path("already_tool"), /class AlreadyTool < ApplicationMCPTool/
  end

  test "generator uses description option" do
    run_generator [ "DescTest", "--description=A test tool" ]
    assert_file generated_tool_path("desc_test"), /description "A test tool"/
  end

  test "generator sets read_only and destructive annotations" do
    run_generator %w[AnnTest --read_only --destructive]
    assert_file generated_tool_path("ann_test"), /read_only$/
    assert_file generated_tool_path("ann_test"), /destructive$/
  end

  test "generator sets category annotation" do
    run_generator %w[CatTest --category=utility]
    assert_file generated_tool_path("cat_test"), /annotate\(:category, "utility"\)/
  end

  test "generator parses properties option" do
    run_generator [
      "PropTest",
      "--properties",
      "foo:string:Foo description:true",
      "bar:integer:Bar description:false"
    ]
    assert_file generated_tool_path("prop_test"),
                /property :foo, type: "string", description: "Foo description", required: true/
    assert_file generated_tool_path("prop_test"), /property :bar, type: "integer", description: "Bar description"/
    assert_file generated_tool_path("prop_test"), /property :bar(?!.*required: true)/m
  end

  test "generator with --ui emits renders_ui" do
    run_generator %w[Weather --ui=ui://views/weather-dashboard]
    assert_file generated_tool_path("weather"), %r{^  renders_ui "ui://views/weather-dashboard"$}
  end

  test "generator without --ui includes commented renders_ui example" do
    run_generator %w[Plain]
    assert_file generated_tool_path("plain") do |content|
      assert_match(%r{# renders_ui "ui://views/my-view"}, content)
      assert_no_match(/^  renders_ui/, content)
    end
  end
end
