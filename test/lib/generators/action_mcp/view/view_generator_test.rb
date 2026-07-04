# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/action_mcp/view/view_generator"

class ViewGeneratorTest < Rails::Generators::TestCase
  tests ActionMCP::Generators::ViewGenerator
  destination File.expand_path("../../../../../tmp/generator_test_output", __dir__)
  setup :prepare_destination

  test "generator creates resource template and view pair" do
    run_generator %w[WeatherDashboard]

    assert_file "app/mcp/resource_templates/weather_dashboard_template.rb" do |content|
      assert_match(/class WeatherDashboardTemplate < ApplicationMCPResTemplate/, content)
      assert_match(%r{uri_template "ui://views/weather-dashboard"}, content)
      assert_match(/mime_type :mcp_app/, content)
      assert_match(%r{render_ui\(template: "mcp/ui/weather_dashboard"\)}, content)
    end

    assert_file "app/views/mcp/ui/weather_dashboard.html.erb" do |content|
      assert_match(/<!doctype html>/, content)
      assert_match(/<%= mcp_app_bridge_tag %>/, content)
      assert_match(/ActionMCP\.connect/, content)
    end
  end

  test "generator strips Template suffix from view name and URI" do
    run_generator %w[StatusTemplate]

    assert_file "app/mcp/resource_templates/status_template.rb" do |content|
      assert_match(/class StatusTemplate < ApplicationMCPResTemplate/, content)
      assert_match(%r{uri_template "ui://views/status"}, content)
      assert_match(%r{render_ui\(template: "mcp/ui/status"\)}, content)
    end
    assert_file "app/views/mcp/ui/status.html.erb"
  end

  test "generator handles snake_case input" do
    run_generator %w[order_summary]

    assert_file "app/mcp/resource_templates/order_summary_template.rb",
                /class OrderSummaryTemplate < ApplicationMCPResTemplate/
    assert_file "app/views/mcp/ui/order_summary.html.erb"
  end

  test "generated view resolves generator-time ERB but keeps runtime helpers" do
    run_generator %w[Chart]

    assert_file "app/views/mcp/ui/chart.html.erb" do |content|
      # Generator-time interpolations must be resolved...
      assert_no_match(/base_name|class_name|uri_name/, content)
      assert_match(/<h1>Chart<\/h1>/, content)
      # ...while the runtime helper call survives as ERB.
      assert_match(/<%= mcp_app_bridge_tag %>/, content)
    end
  end
end
