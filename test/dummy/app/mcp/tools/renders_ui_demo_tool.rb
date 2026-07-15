# frozen_string_literal: true

class RendersUiDemoTool < ApplicationMCPTool
  tool_name "renders_ui_demo"
  description "Demo tool exercising renders_ui with visibility and meta composition"

  meta foo: "bar"
  renders_ui "ui://demo/panel", visibility: %i[model app]

  def perform
    render text: "renders_ui_demo panel is live"
    render structured: { message: "renders_ui_demo panel is live ✓" }
  end
end
