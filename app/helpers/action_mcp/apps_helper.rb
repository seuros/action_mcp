# frozen_string_literal: true

module ActionMCP
  # View helpers for MCP Apps UI templates rendered via `render_ui`.
  module AppsHelper
    # Inlines the vendored @modelcontextprotocol/ext-apps browser bundle and a
    # small bootstrap into a single <script type="module"> element.
    #
    # UI view HTML is delivered to hosts as resource text (not over HTTP), so
    # the bridge must ship inline — external scripts would require CSP-declared
    # origins and a reachable asset host.
    #
    # The bootstrap exposes `globalThis.ActionMCP`:
    #   App           - the raw ext-apps App class
    #   bridgeVersion - vendored package version
    #   connect(opts) - registers opts.handlers on a new App instance BEFORE
    #                   calling connect(), per the ext-apps handshake contract,
    #                   then resolves with the connected app.
    #
    # Views run their own module script after this tag; module scripts execute
    # in document order, so `ActionMCP` is always defined by then.
    #
    # @example In a view
    #   <%= mcp_app_bridge_tag %>
    #   <script type="module">
    #     const app = await ActionMCP.connect({
    #       handlers: { ontoolresult: (result) => { ... } }
    #     });
    #   </script>
    def mcp_app_bridge_tag(app_name: "action-mcp-view", app_version: "1.0.0")
      default_app_info = { name: app_name, version: app_version }.to_json
      bootstrap = <<~JS
        globalThis.ActionMCP = Object.freeze({
          App,
          bridgeVersion: #{Apps::BRIDGE_VERSION.to_json},
          async connect({ appInfo, capabilities, handlers } = {}) {
            const app = new App(appInfo ?? #{default_app_info}, capabilities ?? {});
            if (handlers) Object.assign(app, handlers);
            await app.connect();
            return app;
          }
        });
      JS

      content_tag(:script, "#{Apps.bridge_source}\n#{bootstrap}".html_safe, type: "module")
    end
  end
end
