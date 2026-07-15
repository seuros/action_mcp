# frozen_string_literal: true

require "test_helper"
require "json"
require "rake"

class ActionMCPTasksTest < ActiveSupport::TestCase
  TASK_FILES = %w[action_mcp_tasks.rake action_mcp_apps.rake].map do |filename|
    File.expand_path("../../../lib/tasks/#{filename}", __dir__)
  end.freeze

  setup do
    @original_rake_application = Rake.application
    @original_rails_env = Rails.env

    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    TASK_FILES.each { |task_file| load task_file }
  end

  teardown do
    Rails.env = @original_rails_env
    Rake.application = @original_rake_application
  end

  test "list_widgets shows registered widgets and their linked tools" do
    output = invoke_task("action_mcp:list_widgets")

    assert_includes output, "ACTION MCP UI WIDGETS"
    assert_includes output, "color_palette"
    assert_includes output, "ui://views/color-palette"
    assert_match(/Linked tools:\s+color_palette/, output)
    assert_includes output, "demo_panel"
    assert_includes output, "ui://demo/panel"
    assert_match(/Linked tools:\s+renders_ui_demo.*model.*app/, output)

    widget_names = %w[color_palette demo_panel ui_origins_demo weather_dashboard widget_lab]
    positions = widget_names.map { |name| output.index(name) }

    assert positions.all?, "expected every fixture widget in output:\n#{output}"
    assert_equal positions.sort, positions, "expected widgets to be sorted by name"
  end

  test "list includes the UI widget listing" do
    output = invoke_task("action_mcp:list")

    assert_includes output, "ACTION MCP TOOLS"
    assert_includes output, "ACTION MCP UI WIDGETS"
    assert_includes output, "ACTION MCP PROFILES"
  end

  test "info reports the live configuration for the booted Rails environment" do
    output = invoke_task("action_mcp:info")

    assert_includes output, "ActionMCP Configuration (test)"
    assert_includes output, "Name: ActionMCP Dummy"
    assert_includes output, "MCP Apps:"
    assert_includes output, "Views Path:"
    refute_includes output, "Pub/Sub Adapter:"
    assert_equal @original_rails_env, Rails.env
  end

  test "info requires Rails to boot in a requested environment" do
    _stdout, stderr = capture_io do
      error = assert_raises(SystemExit) do
        Rake::Task["action_mcp:info"].invoke("development")
      end

      refute error.success?
    end

    assert_includes stderr, "RAILS_ENV=development bin/rails action_mcp:info"
    assert_equal @original_rails_env, Rails.env
  end

  test "list_widgets matches concrete tool URIs to parameterized UI templates" do
    with_registry_snapshot do
      widget = Class.new(ActionMCP::ResourceTemplate) do
        def self.name = "TaskParameterizedTemplate"

        description "Parameterized task widget"
        uri_template "ui://task-widgets/{id}"
        mime_type :mcp_app
      end
      ActionMCP::ResourceTemplatesRegistry.register(widget)

      Class.new(ActionMCP::Tool) do
        tool_name "task_parameterized_tool"
        description "Tool linked to one parameterized widget instance"
        renders_ui "ui://task-widgets/42"
      end

      output = invoke_task("action_mcp:list_widgets")

      assert_match(/task_parameterized:.*ui:\/\/task-widgets\/\{id\}.*Linked tools: task_parameterized_tool/m, output)
      refute_match(/MISSING UI WIDGET RESOURCES.*ui:\/\/task-widgets\/42/m, output)
    end
  end

  test "list_widgets links a compiled view through its resolved manifest URI" do
    with_registry_snapshot do
      widget = Class.new(ActionMCP::ResourceTemplate) do
        def self.name = "TaskCompiledTemplate"

        description "Compiled task widget"
        uri_template "ui://views/task-compiled.html?v=abc123"
        mime_type :mcp_app
      end
      ActionMCP::ResourceTemplatesRegistry.register(widget)

      Class.new(ActionMCP::Tool) do
        tool_name "task_compiled_tool"
        description "Tool linked to a compiled widget"
        renders_ui "ui://views/task-compiled"
      end

      resolver = lambda do |uri|
        uri == "ui://views/task-compiled" ? "ui://views/task-compiled.html?v=abc123" : uri
      end
      output = ActionMCP::Apps::ViewManifest.stub(:resolve_resource_uri, resolver) do
        invoke_task("action_mcp:list_widgets")
      end

      assert_match(/task_compiled:.*task-compiled\.html\?v=abc123.*Linked tools: task_compiled_tool/m, output)
    end
  end

  test "apps schema eager loads and emits tools sorted by name" do
    eager_loaded = false
    output = Rails.application.stub(:eager_load!, -> { eager_loaded = true }) do
      invoke_task("action_mcp:apps:schema")
    end
    schema = JSON.parse(output)
    tool_names = schema.fetch("tools").map { |tool| tool.fetch("name") }

    assert eager_loaded
    assert_equal tool_names.sort, tool_names
    assert_includes tool_names, "color_palette"
  end

  private

  def invoke_task(name, *arguments)
    stdout, stderr = capture_io { Rake::Task[name].invoke(*arguments) }
    assert_empty stderr
    stdout
  end

  def with_registry_snapshot
    tools = ActionMCP::ToolsRegistry.tools.dup
    resources = ActionMCP::ResourceTemplatesRegistry.resource_templates.dup
    registered_templates = ActionMCP::ResourceTemplate.registered_templates.dup

    yield
  ensure
    ActionMCP::ToolsRegistry.instance_variable_set(:@items, tools)
    ActionMCP::ResourceTemplatesRegistry.instance_variable_set(:@items, resources)
    ActionMCP::ResourceTemplate.instance_variable_set(:@registered_templates, registered_templates)
  end
end
