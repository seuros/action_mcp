# frozen_string_literal: true

# Fixture template used by McpAppsTest to verify the `ui` macro accepts
# the full set of http/https origin forms (plain, wildcard subdomain,
# port, path). Not part of any feature — exists solely so the test suite
# has a concrete, named class to assert against instead of an anonymous
# `Class.new`, which would otherwise leak into ResourceTemplatesRegistry
# under an empty-string capability_name.
class UiOriginsDemoTemplate < ApplicationMCPResTemplate
  description "Fixture exercising the `ui` macro's CSP origin parser"
  uri_template "ui://demo/csp-origins"
  mime_type :mcp_app

  ui csp: {
    connectDomains: %w[https://api.example.com http://localhost:3000],
    resourceDomains: %w[https://*.cloudflare.com https://cdn.example.com/static]
  }

  def resolve
    render_ui(text: "<!doctype html><title>csp-origins fixture</title>")
  end
end
