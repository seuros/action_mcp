# frozen_string_literal: true

module ActionMCP
  # Engine-owned MIME type registry. Keeps protocol-level MIME values out of
  # Rails' global `Mime::Type` registry while still letting the DSL accept
  # short symbols. For symbols not in our table, falls back to Rails' global
  # registry so apps can still use their own registered formats.
  module MimeTypes
    APP_HTML = "text/html;profile=mcp-app" # MCP Apps (ext-apps, SEP-1865)

    TYPES = {
      mcp_app: APP_HTML
    }.freeze

    # Resolve a user-supplied MIME value to a wire string.
    #
    # @param value [Symbol, String, Mime::Type]
    # @return [String]
    def self.resolve(value)
      case value
      when Symbol
        TYPES[value] || Mime[value]&.to_s || raise(KeyError, "unknown MIME type: #{value.inspect}")
      when Mime::Type
        value.to_s
      else
        value.to_s
      end
    end
  end
end
