# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/action_mcp/resource_template/resource_template_generator"

class ResourceTemplateGeneratorTest < Rails::Generators::TestCase
  tests ActionMCP::Generators::ResourceTemplateGenerator
  include GeneratorTestDestination

  def generated_template_path(name)
    generated_component_path(name, "template", "resource_templates")
  end


  test "generator creates resource template file with correct class name" do
    run_generator %w[MyResource]
    assert_file generated_template_path("my_resource"), /class MyResourceTemplate < ApplicationMCPResTemplate/
  end

  test "generator appends Template to class name if not present" do
    run_generator %w[Another]
    assert_file generated_template_path("another"), /class AnotherTemplate < ApplicationMCPResTemplate/
  end

  test "generator does not double Template in class name" do
    run_generator %w[AlreadyTemplate]
    assert_file generated_template_path("already_template"), /class AlreadyTemplate < ApplicationMCPResTemplate/
  end

  test "generator creates proper file structure" do
    run_generator %w[Product]
    assert_file generated_template_path("product") do |content|
      assert_match(/class ProductTemplate < ApplicationMCPResTemplate/, content)
      assert_match(/template_name "product"/, content)
      assert_match(/description "Access product information"/, content)
      assert_match(%r{uri_template "app://products/{product_id}"}, content)
      assert_match(%r{mime_type "application/json"}, content)
      assert_match(/parameter :product_id,\s+description: "Product identifier",\s+required: true/m, content)
      assert_match(/def resolve/, content)
      assert_match(/ActionMCP::Content::Resource\.new/, content)
    end
  end

  test "generator creates file with snake_case naming" do
    run_generator %w[UserProfile]
    assert_file generated_template_path("user_profile")
  end

  test "generator creates file with proper camelized class name" do
    run_generator %w[user_profile]
    assert_file generated_template_path("user_profile"), /class UserProfileTemplate < ApplicationMCPResTemplate/
  end

  test "generator with --ui creates an MCP Apps template" do
    run_generator %w[WeatherDashboard --ui]
    assert_file generated_template_path("weather_dashboard") do |content|
      assert_match(/class WeatherDashboardTemplate < ApplicationMCPResTemplate/, content)
      assert_match(%r{uri_template "ui://views/weather-dashboard"}, content)
      assert_match(/mime_type :mcp_app/, content)
      assert_match(/render_ui\(text:/, content)
    end
  end

  test "generator with --ui strips Template suffix from URI" do
    run_generator %w[PanelTemplate --ui]
    assert_file generated_template_path("panel_template") do |content|
      assert_match(%r{uri_template "ui://views/panel"}, content)
    end
  end

  test "generator without --ui keeps the default app template" do
    run_generator %w[Product]
    assert_file generated_template_path("product") do |content|
      assert_no_match(/render_ui/, content)
      assert_match(%r{uri_template "app://products/{product_id}"}, content)
    end
  end
end
