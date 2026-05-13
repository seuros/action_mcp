# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class McpAppsTest < ActiveSupport::TestCase
    include ActionMCP::TestHelper

    test "weather tool declares renders_ui pointing at the dashboard" do
      assert_equal({ ui: { resourceUri: "ui://weather/dashboard" } }, WeatherTool.to_h[:_meta])
    end

    test "renders_ui never emits the deprecated flat ui/resourceUri key" do
      meta = WeatherTool.to_h[:_meta]
      refute meta.key?("ui/resourceUri")
      refute meta.key?(:"ui/resourceUri")
    end

    test "renders_ui serializes resourceUri and visibility under _meta.ui" do
      assert_equal(
        { resourceUri: "ui://demo/panel", visibility: [ "model", "app" ] },
        RendersUiDemoTool.to_h.dig(:_meta, :ui)
      )
    end

    test "renders_ui composes with meta on orthogonal keys" do
      assert_equal "bar", RendersUiDemoTool.to_h.dig(:_meta, :foo)
    end

    test "weather dashboard resolves to HTML content with content-level _meta.ui" do
      response = resolve_mcp_resource("ui://weather/dashboard")
      content = response.contents.first

      assert_equal MIME_TYPE_APP_HTML, content.mime_type
      refute_empty content.text
      assert_equal({ csp: { connectDomains: [ "https://api.openweathermap.org" ] }, prefersBorder: true },
                   content.meta[:ui])
    end

    test "renders_ui rejects non-String URI" do
      assert_raises(ArgumentError) { RendersUiDemoTool.renders_ui :"ui://widgets/panel" }
      assert_raises(ArgumentError) { RendersUiDemoTool.renders_ui nil }
    end

    test "renders_ui rejects non-ui:// URI" do
      assert_raises(ArgumentError) { RendersUiDemoTool.renders_ui "http://widgets/panel" }
      assert_raises(ArgumentError) { RendersUiDemoTool.renders_ui "" }
    end

    test "renders_ui rejects unknown visibility values" do
      assert_raises(ArgumentError) do
        RendersUiDemoTool.renders_ui "ui://widgets/panel", visibility: %i[model agent]
      end
    end

    # The rejection tests target the validation invoked by the `ui` macro.
    # `validate_ui_csp_origins!` raises before any state is merged into
    # `@ui_meta`, so calling `.ui csp: { bad }` on a real fixture template is
    # safe — no mutation leaks across tests.
    test "ui macro rejects CSP origins without scheme" do
      assert_raises(ArgumentError) do
        UiOriginsDemoTemplate.ui csp: { connectDomains: %w[api.example.com] }
      end
    end

    test "ui macro rejects non-http schemes in CSP origins" do
      assert_raises(ArgumentError) do
        UiOriginsDemoTemplate.ui csp: { connectDomains: %w[wss://stream.example.com] }
      end
      assert_raises(ArgumentError) do
        UiOriginsDemoTemplate.ui csp: { resourceDomains: %w[ftp://files.example.com] }
      end
    end

    test "ui macro accepts http/https origins, wildcards, ports, and paths" do
      connect = UiOriginsDemoTemplate.ui_meta[:csp][:connectDomains]
      resource = UiOriginsDemoTemplate.ui_meta[:csp][:resourceDomains]

      assert_includes connect, "https://api.example.com"
      assert_includes connect, "http://localhost:3000"
      assert_includes resource, "https://*.cloudflare.com"
      assert_includes resource, "https://cdn.example.com/static"
    end

    test "client_supports_ui? is true when the extension key is present" do
      assert capability_for(extensions: { "io.modelcontextprotocol/ui" => {} }).client_supports_ui?
    end

    test "client_supports_ui? is false when the extension key is absent" do
      refute capability_for(extensions: { "tools" => {} }).client_supports_ui?
    end

    test "client_supports_ui? is false when there is no session" do
      refute Capability.new.client_supports_ui?
    end

    test "client_supports_ui? is false when client_capabilities is nil" do
      session = Session.new(protocol_version: "2025-06-18")
      session.client_capabilities = nil

      refute Capability.new.with_context(session: session).client_supports_ui?
    end

    private

    def capability_for(extensions:)
      session = Session.new(protocol_version: "2025-06-18")
      session.client_capabilities = { "extensions" => extensions }
      Capability.new.with_context(session: session)
    end
  end
end
