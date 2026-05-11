# frozen_string_literal: true

module ActionMCP
  # Constants for the MCP Apps extension (ext-apps, SEP-1865, draft 2026-01-26).
  # See: https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/draft/apps.mdx
  module Apps
    EXTENSION_KEY = "io.modelcontextprotocol/ui"
    VISIBILITY_VALUES = %w[model app].freeze
    URI_SCHEME = %r{\Aui://\S+\z}
    MIME_TYPE = MimeTypes::APP_HTML

    # `_meta.ui.csp` directive keys per ext-apps spec.
    CSP_KEYS = %i[connectDomains resourceDomains frameDomains baseUriDomains].freeze

    # Accepts http/https origins only. Wildcard subdomain (`https://*.example.com`),
    # ports, and paths are allowed. WebSocket origins (ws://, wss://) are not
    # accepted by ActionMCP — declare them via `ws://` over fetch if you must.
    ORIGIN_PATTERN = %r{\Ahttps?://[^\s"'<>]+\z}
  end
end
