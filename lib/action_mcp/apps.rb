# frozen_string_literal: true

module ActionMCP
  # Constants and helpers for the MCP Apps extension (ext-apps, SEP-1865,
  # stable 2026-01-26).
  # See: https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx
  module Apps
    EXTENSION_KEY = "io.modelcontextprotocol/ui"
    VISIBILITY_VALUES = %w[model app].freeze
    URI_SCHEME = %r{\Aui://\S+\z}
    MIME_TYPE = MimeTypes::APP_HTML
    EXTENSION_SETTINGS = { mimeTypes: [ MIME_TYPE ] }.freeze

    # `_meta.ui.csp` directive keys per ext-apps spec.
    CSP_KEYS = %i[connectDomains resourceDomains frameDomains baseUriDomains].freeze
    PERMISSION_KEYS = %i[camera microphone geolocation clipboardWrite].freeze

    # The stable MCP Apps spec allows WebSocket endpoints for connect-src only.
    CONNECT_ORIGIN_PATTERN = %r{\A(?:https?|wss?)://[^\s"'<>]+\z}
    RESOURCE_ORIGIN_PATTERN = %r{\Ahttps?://[^\s"'<>]+\z}

    module_function

    def extension_settings
      EXTENSION_SETTINGS.deep_dup
    end

    def client_supports?(client_capabilities)
      settings = client_capabilities&.dig("extensions", EXTENSION_KEY) ||
                 client_capabilities&.dig(:extensions, EXTENSION_KEY)
      return false unless settings.is_a?(Hash)

      mime_types = settings["mimeTypes"] || settings[:mimeTypes]
      Array(mime_types).include?(MIME_TYPE)
    end
  end
end
