# frozen_string_literal: true

# Opens the compiled demo view (app/mcp/views/demo.ts).
class DemoCounterTool < ApplicationMCPTool
  tool_name "demo_counter"
  description "Opens the click counter demo view"

  renders_ui "ui://views/demo"

  def perform
    render structured: { message: "demo counter ready" }
  end
end
