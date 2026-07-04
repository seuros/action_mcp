# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Apps
    class ViewManifestTest < ActiveSupport::TestCase
      setup do
        @dir = Dir.mktmpdir("action_mcp_views")
        @bundle = "dashboard-8f3a91c2.js"
        File.write(File.join(@dir, @bundle), 'console.log("dash"); const s = "</script>";')
      end

      teardown do
        ViewManifest.send(:evict_generated_templates!)
        FileUtils.remove_entry(@dir)
      end

      def write_manifest(views: default_views, schema_version: 1)
        File.write(
          File.join(@dir, "manifest.json"),
          JSON.generate({ schemaVersion: schema_version, generator: "@action-mcp/vite-plugin", views: views })
        )
      end

      def default_views
        {
          "dashboard" => {
            "file" => @bundle,
            "hash" => "8f3a91c2",
            "uri" => "ui://views/dashboard.html?v=8f3a91c2",
            "logicalUri" => "ui://views/dashboard",
            "ui" => { "csp" => { "connectDomains" => [ "https://api.example.com" ] }, "prefersBorder" => true }
          }
        }
      end

      test "load! returns empty when no manifest exists" do
        assert_empty ViewManifest.load!(@dir)
      end

      test "load! registers a template per view with manifest metadata" do
        write_manifest
        classes = ViewManifest.load!(@dir)

        assert_equal 1, classes.size
        klass = classes.first
        assert_equal "ActionMCP::Apps::Views::DashboardView", klass.name
        assert_equal "ui://views/dashboard.html?v=8f3a91c2", klass.uri_template
        assert_equal ActionMCP::Apps::MIME_TYPE, klass.mime_type
        assert_includes ResourceTemplate.registered_templates, klass
        assert_equal klass, ResourceTemplatesRegistry.find_template_for_uri(klass.uri_template)
        assert_equal klass, ResourceTemplatesRegistry.items["dashboard_view"]
      end

      test "load! registers multiple compiled views without registry collisions" do
        second_bundle = "settings-1234abcd.js"
        File.write(File.join(@dir, second_bundle), "console.log('settings');")
        write_manifest(views: default_views.merge(
          "settings" => {
            "file" => second_bundle,
            "hash" => "1234abcd",
            "uri" => "ui://views/settings.html?v=1234abcd",
            "logicalUri" => "ui://views/settings"
          }
        ))

        dashboard, settings = ViewManifest.load!(@dir)

        assert_equal dashboard, ResourceTemplatesRegistry.find_template_for_uri(dashboard.uri_template)
        assert_equal settings, ResourceTemplatesRegistry.find_template_for_uri(settings.uri_template)
        assert_equal dashboard, ResourceTemplatesRegistry.items["dashboard_view"]
        assert_equal settings, ResourceTemplatesRegistry.items["settings_view"]
      end

      test "registered template matches its literal URI including query" do
        write_manifest
        klass = ViewManifest.load!(@dir).first

        assert klass.readable_uri?("ui://views/dashboard.html?v=8f3a91c2")
        refute klass.readable_uri?("ui://views/dashboard.html?v=deadbeef")
        refute klass.readable_uri?("ui://views/dashboardXhtml?v=8f3a91c2"),
               "literal dot must not act as regex wildcard"
      end

      test "resolve inlines the bundle into an HTML shell" do
        write_manifest
        klass = ViewManifest.load!(@dir).first
        resource = klass.new.resolve

        assert_equal ActionMCP::Apps::MIME_TYPE, resource.mime_type
        assert_includes resource.text, '<div id="root">'
        assert_includes resource.text, 'console.log("dash")'
        refute_includes resource.text.sub('<script type="module">', "").sub("</script>", ""), "</script>",
                        "bundle content must have script closers neutralized"
        assert_equal({ ui: { csp: { connectDomains: [ "https://api.example.com" ] }, prefersBorder: true } },
                     resource.meta)
      end

      test "load! is idempotent across rebuilds with changed hashes" do
        write_manifest
        ViewManifest.load!(@dir)

        new_bundle = "dashboard-deadbeef.js"
        File.write(File.join(@dir, new_bundle), "console.log('v2');")
        write_manifest(views: {
                         "dashboard" => {
                           "file" => new_bundle, "hash" => "deadbeef",
                           "uri" => "ui://views/dashboard.html?v=deadbeef"
                         }
                       })

        classes = ViewManifest.load!(@dir)
        assert_equal 1, classes.size
        assert_equal "ui://views/dashboard.html?v=deadbeef", classes.first.uri_template
        assert_equal "ui://views/dashboard.html?v=deadbeef",
                     ViewManifest.resolve_resource_uri("ui://views/dashboard")
        generated = ResourceTemplate.registered_templates.select { |k| k.name&.start_with?("ActionMCP::Apps::Views::") }
        assert_equal 1, generated.size, "old hash registration must be evicted"
        assert_equal classes.first, ResourceTemplatesRegistry.find_template_for_uri(classes.first.uri_template)
        assert_nil ResourceTemplatesRegistry.find_template_for_uri("ui://views/dashboard.html?v=8f3a91c2")
      end

      test "logical URI resolves to the exact registered resource URI" do
        write_manifest
        ViewManifest.load!(@dir)

        assert_equal "ui://views/dashboard.html?v=8f3a91c2",
                     ViewManifest.resolve_resource_uri("ui://views/dashboard")
        assert_equal "ui://other/view", ViewManifest.resolve_resource_uri("ui://other/view")
      end

      test "tool metadata resolves through the loaded manifest alias" do
        views = default_views
        views["dashboard"]["logicalUri"] = "ui://weather/dashboard"
        write_manifest(views: views)
        ViewManifest.load!(@dir)

        assert_equal "ui://views/dashboard.html?v=8f3a91c2",
                     ::WeatherTool.to_h.dig(:_meta, :ui, :resourceUri)
        assert_equal "ui://weather/dashboard", ::WeatherTool._meta.dig(:ui, :resourceUri)
      end

      test "removing the manifest evicts generated templates and URI aliases" do
        write_manifest
        klass = ViewManifest.load!(@dir).first
        FileUtils.rm_f(File.join(@dir, "manifest.json"))

        assert_empty ViewManifest.load!(@dir)
        assert_nil ResourceTemplatesRegistry.find_template_for_uri(klass.uri_template)
        refute_includes ResourceTemplate.registered_templates, klass
        refute Views.const_defined?(:DashboardView, false)
        assert_equal "ui://views/dashboard", ViewManifest.resolve_resource_uri("ui://views/dashboard")
      end

      test "load! raises on unsupported schemaVersion" do
        write_manifest(schema_version: 99)
        error = assert_raises(ViewManifest::Error) { ViewManifest.load!(@dir) }
        assert_match(/schemaVersion 99/, error.message)
      end

      test "load! raises when a bundle file is missing" do
        write_manifest(views: {
                         "ghost" => { "file" => "ghost-123.js", "hash" => "123", "uri" => "ui://views/ghost.html?v=123" }
                       })
        error = assert_raises(ViewManifest::Error) { ViewManifest.load!(@dir) }
        assert_match(/missing bundle/, error.message)
      end

      test "load! raises on invalid ui metadata from manifest" do
        views = default_views
        views["dashboard"]["ui"] = { "csp" => { "connectDomains" => [ "javascript:alert(1)" ] } }
        write_manifest(views: views)

        assert_raises(ArgumentError) { ViewManifest.load!(@dir) }
        assert_nil ResourceTemplatesRegistry.find_template_for_uri("ui://views/dashboard.html?v=8f3a91c2")
      end

      test "load! rejects unknown ui metadata keys from manifest" do
        views = default_views
        views["dashboard"]["ui"] = { "futureMode" => "fullscreen" }
        write_manifest(views: views)

        assert_raises(ArgumentError) { ViewManifest.load!(@dir) }
        assert_nil ResourceTemplatesRegistry.find_template_for_uri("ui://views/dashboard.html?v=8f3a91c2")
      end
    end
  end
end
