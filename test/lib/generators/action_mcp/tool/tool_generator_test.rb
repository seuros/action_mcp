# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/action_mcp/tool/tool_generator"

class ToolGeneratorTest < Rails::Generators::TestCase
  tests ActionMCP::Generators::ToolGenerator
  destination File.expand_path("../../../../../tmp/generator_test_output", __dir__)
  setup :prepare_destination

  def generated_tool_path(name)
    base = name.underscore
    file = base.end_with?("_tool") ? base : "#{base}_tool"
    File.join(destination_root, "app/mcp/tools/#{file}.rb")
  end

  def run_generator_with_args(args)
    run_generator args
  end

  test "generator creates tool file with correct class name" do
    run_generator_with_args %w[MyCustom]
    assert_file generated_tool_path("my_custom"), /class MyCustomTool < ApplicationMCPTool/
  end

  test "generator appends Tool to class name if not present" do
    run_generator_with_args %w[Another]
    assert_file generated_tool_path("another"), /class AnotherTool < ApplicationMCPTool/
  end

  test "generator does not double Tool in class name" do
    run_generator_with_args %w[AlreadyTool]
    assert_file generated_tool_path("already_tool"), /class AlreadyTool < ApplicationMCPTool/
  end

  test "generator uses description option" do
    run_generator_with_args %w[DescTest --description=A\ test\ tool]
    assert_file generated_tool_path("desc_test"), /description "A test tool"/
  end

  test "generator sets read_only and destructive annotations" do
    run_generator_with_args %w[AnnTest --read_only --destructive]
    assert_file generated_tool_path("ann_test"), /read_only$/
    assert_file generated_tool_path("ann_test"), /destructive$/
  end

  test "generator sets category annotation" do
    run_generator_with_args %w[CatTest --category=utility]
    assert_file generated_tool_path("cat_test"), /annotate\(:category, "utility"\)/
  end

  test "generator parses properties option" do
    run_generator_with_args [
      "PropTest",
      "--properties",
      "foo:string:Foo description:true",
      "bar:integer:Bar description:false"
    ]
    assert_file generated_tool_path("prop_test"), /property :foo, type: "string", description: "Foo description", required: true/
    assert_file generated_tool_path("prop_test"), /property :bar, type: "integer", description: "Bar description"/
    assert_file generated_tool_path("prop_test"), /property :bar(?!.*required: true)/m
  end
end
