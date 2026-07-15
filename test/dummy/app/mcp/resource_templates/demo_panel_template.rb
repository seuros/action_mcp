# frozen_string_literal: true

# Backing view for RendersUiDemoTool (ui://demo/panel). Without this template
# the tool's renders_ui pointer dangled and the widget failed to load.
class DemoPanelTemplate < ApplicationMCPResTemplate
  description "Minimal MCP Apps panel for the renders_ui_demo tool"
  uri_template "ui://demo/panel"
  mime_type :mcp_app

  def resolve
    render_ui(template: "mcp/ui/demo_panel")
  end
end
