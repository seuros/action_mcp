# frozen_string_literal: true

require "test_helper"
require "open3"

class DeferredComponentLoadingBootTest < ActiveSupport::TestCase
  DUMMY_ROOT = File.expand_path("../dummy", __dir__)

  BOOT_SCRIPT = <<~'RUBY'
    require File.join(ENV.fetch("DUMMY_ROOT"), "config/application")

    ActionMCP.configuration.mcp_apps_views_path = ENV.fetch("VIEWS_DIR")
    tools_defined_during_boot = []
    ActiveSupport.on_load(:action_mcp_tool) { tools_defined_during_boot << name unless Rails.application.initialized? }

    Rails.application.initialize!

    snapshot = lambda do
      {
        deferred: ActionMCP.configuration.mcp_components_deferred?,
        weather_tool_loaded: Object.autoload?(:WeatherForecastTool).nil?,
        tools: ActionMCP::ToolsRegistry.store.keys,
        resource_templates: ActionMCP::ResourceTemplatesRegistry.store.keys
      }
    end

    boot = snapshot.call.merge(tools_defined_during_boot: tools_defined_during_boot)
    found = ActionMCP::ToolsRegistry.find("weather_forecast").name
    File.write(ENV.fetch("RESULT_PATH"), JSON.generate(boot: boot, found: found, after_read: snapshot.call))
  RUBY

  def maxitest_timeout = 60

  setup do
    @dir = Dir.mktmpdir("action_mcp_deferred_boot")
    @views = File.join(@dir, "views")
    FileUtils.mkdir_p(@views)
    File.write(File.join(@views, "dashboard-8f3a91c2.js"), "console.log('dash');")
    File.write(File.join(@views, "manifest.json"), JSON.generate(
      schemaVersion: 1,
      views: { "dashboard" => { "file" => "dashboard-8f3a91c2.js", "uri" => "ui://views/dashboard.html?v=8f3a91c2" } }
    ))
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test "a development boot defers app/mcp to the first registry read" do
    result_path = File.join(@dir, "result.json")
    env = {
      "RAILS_ENV" => "development",
      "DUMMY_ROOT" => DUMMY_ROOT,
      "VIEWS_DIR" => @views,
      "RESULT_PATH" => result_path
    }

    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, "-e", BOOT_SCRIPT, chdir: DUMMY_ROOT)
    assert_predicate status, :success?, "boot failed:\n#{stderr}\n#{stdout.lines.last(20).join}"

    result = JSON.parse(File.read(result_path))
    boot = result["boot"]
    after_read = result["after_read"]

    assert boot["deferred"]
    refute boot["weather_tool_loaded"]
    assert_empty boot["tools"]
    assert_empty boot["tools_defined_during_boot"]
    assert_equal [ "dashboard_view" ], boot["resource_templates"]

    assert_equal "WeatherForecastTool", result["found"]
    refute after_read["deferred"]
    assert after_read["weather_tool_loaded"]
    assert_includes after_read["tools"], "weather_forecast"
    assert_includes after_read["resource_templates"], "products"
    assert_includes after_read["resource_templates"], "dashboard_view"
  end
end
