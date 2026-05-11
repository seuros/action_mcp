# frozen_string_literal: true

module ActionMCP
  # Constants for the MCP Apps extension (ext-apps, SEP-1865, draft 2026-01-26).
  # See: https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/draft/apps.mdx
  module Apps
    EXTENSION_KEY = "io.modelcontextprotocol/ui"
    VISIBILITY_VALUES = %w[model app].freeze
    URI_SCHEME = %r{\Aui://\S+\z}
    MIME_TYPE = MimeTypes::APP_HTML
  end
end
