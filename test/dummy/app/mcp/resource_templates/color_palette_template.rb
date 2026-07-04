# frozen_string_literal: true

# MCP Apps view for the color_palette tool.
class ColorPaletteTemplate < ApplicationMCPResTemplate
  description "Interactive color palette widget for the color_palette tool"
  uri_template "ui://views/color-palette"
  mime_type :mcp_app

  # Ask the host for clipboard-write so swatches can copy their hex on click.
  # Hosts may decline; the view feature-detects and falls back.
  ui permissions: { clipboardWrite: {} }

  def resolve
    render_ui(template: "mcp/ui/color_palette")
  end
end
