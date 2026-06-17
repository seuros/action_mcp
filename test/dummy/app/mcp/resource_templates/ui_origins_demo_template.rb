# frozen_string_literal: true

# Fixture template used by McpAppsTest to verify the `ui` macro accepts
# the full set of accepted origin forms (plain, wildcard subdomain,
# port, path, and WebSocket connect origins). Not part of any feature; it
# gives the test suite a concrete, named class to assert against instead of an
# anonymous `Class.new`, which would otherwise leak into ResourceTemplatesRegistry.
class UiOriginsDemoTemplate < ApplicationMCPResTemplate
  description "Fixture exercising the `ui` macro's CSP origin parser"
  uri_template "ui://demo/csp-origins"
  mime_type :mcp_app

  ui csp: {
    connectDomains: %w[https://api.example.com http://localhost:3000 wss://stream.example.com],
    resourceDomains: %w[https://*.cloudflare.com https://cdn.example.com/static]
  }

  def resolve
    render_ui(text: "<!doctype html><title>csp-origins fixture</title>")
  end
end
