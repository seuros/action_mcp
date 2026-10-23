# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class DeferredComponentLoadingTest < ActiveSupport::TestCase
    MCP_PATH = Rails.root.join("app/mcp")

    REGISTRY_READS = {
      "ToolsRegistry.items" => -> { ToolsRegistry.items },
      "ToolsRegistry.tools" => -> { ToolsRegistry.tools },
      "ToolsRegistry.find" => -> { ToolsRegistry.find("weather_forecast") },
      "ToolsRegistry.size" => -> { ToolsRegistry.size },
      "ToolsRegistry.non_abstract" => -> { ToolsRegistry.non_abstract },
      "ToolsRegistry.tool_call" => -> { ToolsRegistry.tool_call("missing_tool", {}) },
      "PromptsRegistry.prompts" => -> { PromptsRegistry.prompts },
      "PromptsRegistry.find" => -> { PromptsRegistry.find("greeting") },
      "PromptsRegistry.prompt_call" => -> { PromptsRegistry.prompt_call("analyze_code", { code: "puts 1" }) },
      "ResourceTemplatesRegistry.resource_templates" => -> { ResourceTemplatesRegistry.resource_templates },
      "ResourceTemplatesRegistry.get_resource_template" => -> { ResourceTemplatesRegistry.get_resource_template("products") },
      "ResourceTemplatesRegistry.find_template_for_uri" => -> { ResourceTemplatesRegistry.find_template_for_uri("ecommerce://products/1") },
      "ActionMCP.tools" => -> { ActionMCP.tools },
      "ActionMCP.prompts" => -> { ActionMCP.prompts },
      "ActionMCP.available_tools" => -> { ActionMCP.available_tools },
      "ActionMCP.available_prompts" => -> { ActionMCP.available_prompts },
      "Configuration#filtered_tools" => -> { ActionMCP.configuration.filtered_tools },
      "Configuration#filtered_prompts" => -> { ActionMCP.configuration.filtered_prompts },
      "Configuration#filtered_resources" => -> { ActionMCP.configuration.filtered_resources }
    }.freeze

    setup do
      @config = Configuration.new
      @loads = []
      @loader = ->(path) { @loads << path }
      @stores = [ ToolsRegistry, PromptsRegistry, ResourceTemplatesRegistry ].index_with { |registry| registry.store.dup }
      @registered_templates = ResourceTemplate.registered_templates.dup
    end

    teardown do
      @stores.each { |registry, store| registry.instance_variable_set(:@items, store) }
      ResourceTemplate.instance_variable_set(:@registered_templates, @registered_templates)
    end

    def booting(eager_load: false, initialized: false, &)
      ActionMCP.stub(:configuration, -> { @config }) do
        Rails.configuration.stub(:eager_load, eager_load) do
          Rails.application.stub(:initialized?, initialized) do
            Rails.autoloaders.main.stub(:eager_load_dir, ->(path) { @loader.call(path) }, &)
          end
        end
      end
    end

    test "booting without eager loading defers app/mcp to the first registry read" do
      booting do
        @config.prepare_mcp_components

        assert_predicate @config, :mcp_components_deferred?
        assert_empty @loads

        assert_equal WeatherForecastTool, ToolsRegistry.find("weather_forecast")
        ToolsRegistry.non_abstract
      end

      assert_equal [ MCP_PATH ], @loads
      refute_predicate @config, :mcp_components_deferred?
    end

    test "booting with eager loading loads app/mcp immediately" do
      booting(eager_load: true) { @config.prepare_mcp_components }

      assert_equal [ MCP_PATH ], @loads
      refute_predicate @config, :mcp_components_deferred?
    end

    test "a prepare after initialization loads app/mcp immediately and drops the pending load" do
      booting { @config.prepare_mcp_components }
      booting(initialized: true) do
        @config.prepare_mcp_components
        assert_equal [ MCP_PATH ], @loads

        ToolsRegistry.items
      end

      assert_equal [ MCP_PATH ], @loads
      refute_predicate @config, :mcp_components_deferred?
    end

    test "nothing is deferred when no profile component includes all" do
      @config.active_profile = :minimal

      booting do
        @config.prepare_mcp_components
        ToolsRegistry.items
      end

      refute_predicate @config, :mcp_components_deferred?
      assert_empty @loads
    end

    test "every registry read runs the pending load first" do
      REGISTRY_READS.each do |read, call|
        @config = Configuration.new
        @loads.clear

        booting do
          @config.prepare_mcp_components
          call.call
        end

        assert_equal [ MCP_PATH ], @loads, "#{read} did not run the deferred load"
      end
    end

    test "registry writes leave the load pending" do
      views = Dir.mktmpdir("action_mcp_views")
      File.write(File.join(views, "probe-1a2b3c4d.js"), "console.log('probe');")
      File.write(File.join(views, "manifest.json"), JSON.generate(
        schemaVersion: 1,
        views: { "deferred_probe" => { "file" => "probe-1a2b3c4d.js", "uri" => "ui://views/deferred_probe.html?v=1a2b3c4d" } }
      ))

      booting do
        @config.prepare_mcp_components

        tool = Class.new(Tool) { tool_name "deferred_probe_tool" }
        prompt = Class.new(Prompt) { prompt_name "deferred_probe_prompt" }
        template = Class.new(ResourceTemplate)
        assert_equal tool, ToolsRegistry.store["deferred_probe_tool"]
        assert_equal prompt, PromptsRegistry.store["deferred_probe_prompt"]
        assert_equal template, ResourceTemplatesRegistry.store[""]

        [ tool, prompt, template ].each(&:abstract!)
        refute_includes ToolsRegistry.store.values, tool
        refute_includes PromptsRegistry.store.values, prompt
        refute_includes ResourceTemplatesRegistry.store.values, template

        view = Apps::ViewManifest.load!(views).first
        assert_equal view, ResourceTemplatesRegistry.store["deferred_probe_view"]

        Apps::ViewManifest.load!(views)
        Apps::ViewManifest.send(:evict_generated_templates!)
        refute ResourceTemplatesRegistry.store.key?("deferred_probe_view")
      end

      assert_predicate @config, :mcp_components_deferred?
      assert_empty @loads
    ensure
      Apps::ViewManifest.send(:evict_generated_templates!)
      FileUtils.remove_entry(views)
    end

    test "a registry read during the load returns without recursing" do
      nested = nil
      @loader = lambda do |path|
        @loads << path
        nested = ToolsRegistry.find("weather_forecast")
      end

      booting do
        @config.prepare_mcp_components
        ToolsRegistry.non_abstract
      end

      assert_equal WeatherForecastTool, nested
      assert_equal [ MCP_PATH ], @loads
    end

    test "a failed load re-raises and the next read retries it" do
      @loader = lambda do |path|
        @loads << path
        raise NameError, "uninitialized constant BrokenTool" if @loads.one?
      end

      booting do
        @config.prepare_mcp_components

        error = assert_raises(NameError) { ToolsRegistry.find("weather_forecast") }
        assert_equal "uninitialized constant BrokenTool", error.message
        assert_predicate @config, :mcp_components_deferred?

        assert_equal WeatherForecastTool, ToolsRegistry.find("weather_forecast")
      end

      assert_equal [ MCP_PATH, MCP_PATH ], @loads
      refute_predicate @config, :mcp_components_deferred?
    end

    test "concurrent first readers wait for the loading thread" do
      entered = Queue.new
      release = Queue.new
      reading = Queue.new
      finished = false
      @loader = lambda do |path|
        @loads << path
        entered << true
        release.pop
        finished = true
      end

      booting do
        @config.prepare_mcp_components

        loading = Thread.new { ToolsRegistry.size }
        entered.pop
        reader = Thread.new do
          reading << true
          ToolsRegistry.find("weather_forecast")
          finished
        end
        reading.pop
        Thread.pass until reader.status == "sleep" || !reader.alive?
        release << true

        assert_predicate loading.value, :positive?
        assert reader.value, "a concurrent reader saw the registry before the load finished"
      end

      assert_equal [ MCP_PATH ], @loads
    end

    test "development reloads app/mcp on every prepare" do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
        booting do
          @config.prepare_mcp_components
          ToolsRegistry.items
        end
        2.times { booting(initialized: true) { @config.prepare_mcp_components } }
      end

      assert_equal [ MCP_PATH ] * 3, @loads
    end

    test "outside development app/mcp loads once" do
      booting do
        @config.prepare_mcp_components
        ToolsRegistry.items
      end
      booting(initialized: true) { @config.prepare_mcp_components }

      assert_equal [ MCP_PATH ], @loads
    end
  end
end
