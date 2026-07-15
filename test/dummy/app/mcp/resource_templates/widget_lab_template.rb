# frozen_string_literal: true

# MCP Apps demo view for the widget_lab tool. Uniquely named so hosts with a
# built-in "weather"-style tool can't shadow it — the only way to reach this
# widget is through this MCP server.
class WidgetLabTemplate < ApplicationMCPResTemplate
  description "Interactive demo panel for the widget_lab tool"
  uri_template "ui://views/widget-lab"
  mime_type :mcp_app

  def resolve
    render_ui(template: "mcp/ui/widget_lab")
  end
end
