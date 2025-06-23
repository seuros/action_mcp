# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/action_mcp/resource_template/resource_template_generator"

class ResourceTemplateGeneratorTest < Rails::Generators::TestCase
  tests ActionMCP::Generators::ResourceTemplateGenerator
  destination File.expand_path("../../../../../tmp/generator_test_output", __dir__)
  setup :prepare_destination

  def generated_template_path(name)
    base = name.underscore
    file = base.end_with?("_template") ? base : "#{base}_template"
    File.join(destination_root, "app/mcp/resource_templates/#{file}.rb")
  end

  def run_generator_with_args(args)
    run_generator args
  end

  test "generator creates resource template file with correct class name" do
    run_generator_with_args %w[MyResource]
    assert_file generated_template_path("my_resource"), /class MyResourceTemplate < ApplicationMCPResTemplate/
  end

  test "generator appends Template to class name if not present" do
    run_generator_with_args %w[Another]
    assert_file generated_template_path("another"), /class AnotherTemplate < ApplicationMCPResTemplate/
  end

  test "generator does not double Template in class name" do
    run_generator_with_args %w[AlreadyTemplate]
    assert_file generated_template_path("already_template"), /class AlreadyTemplate < ApplicationMCPResTemplate/
  end

  test "generator creates proper file structure" do
    run_generator_with_args %w[Product]
    assert_file generated_template_path("product") do |content|
      assert_match(/class ProductTemplate < ApplicationMCPResTemplate/, content)
      assert_match(/template_name "product"/, content)
      assert_match(/description "Access product information"/, content)
      assert_match(/uri_template "app:\/\/products\/{product_id}"/, content)
      assert_match(/mime_type "application\/json"/, content)
      assert_match(/parameter :product_id,\s+description: "Product identifier",\s+required: true/m, content)
      assert_match(/def resolve/, content)
      assert_match(/ActionMCP::Content::Resource\.new/, content)
    end
  end

  test "generator creates file with snake_case naming" do
    run_generator_with_args %w[UserProfile]
    assert_file generated_template_path("user_profile")
  end

  test "generator creates file with proper camelized class name" do
    run_generator_with_args %w[user_profile]
    assert_file generated_template_path("user_profile"), /class UserProfileTemplate < ApplicationMCPResTemplate/
  end
end
