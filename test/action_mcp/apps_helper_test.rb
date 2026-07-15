# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class AppsHelperTest < ActiveSupport::TestCase
    test "bridge_source is memoized, frozen, and safe to inline" do
      source = Apps.bridge_source

      assert_same source, Apps.bridge_source
      assert_predicate source, :frozen?
      refute_includes source, "</script"
      # The bundle's App class export must be present.
      assert_includes source, "ui/initialize"
    end

    test "BRIDGE_VERSION matches the vendored bundle path" do
      assert_equal "1.7.4", Apps::BRIDGE_VERSION
      assert_path_exists Apps::BRIDGE_PATH
    end

    test "mcp_app_bridge_tag renders a module script with bridge and bootstrap" do
      html = MCPAppRenderer.render(inline: "<%= mcp_app_bridge_tag %>")

      assert_includes html, '<script type="module">'
      assert_includes html, "globalThis.ActionMCP"
      assert_includes html, "ui/initialize" # bundle marker
      assert_includes html, %(bridgeVersion: "#{Apps::BRIDGE_VERSION}")
      assert_includes html, %("name":"action-mcp-view")
    end

    test "mcp_app_bridge_tag accepts custom app identity" do
      html = MCPAppRenderer.render(
        inline: "<%= mcp_app_bridge_tag(app_name: 'weather-widget', app_version: '2.1.0') %>"
      )

      assert_includes html, %("name":"weather-widget")
      assert_includes html, %("version":"2.1.0")
    end

    test "handlers are registered before connect in the bootstrap" do
      html = MCPAppRenderer.render(inline: "<%= mcp_app_bridge_tag %>")

      assign_index = html.index("Object.assign(app, handlers)")
      connect_index = html.index("await app.connect()")

      assert assign_index, "bootstrap must register handlers"
      assert connect_index, "bootstrap must connect"
      assert_operator assign_index, :<, connect_index,
                      "handlers must be registered before connect() per ext-apps handshake contract"
    end
  end
end
