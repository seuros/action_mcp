# frozen_string_literal: true

# Uniquely named MCP Apps demo tool. Unlike "weather" (which collides with a
# host's built-in weather tool), nothing shadows "widget_lab", so a UI-capable
# client is forced to call this MCP server and render the linked widget.
class WidgetLabTool < ApplicationMCPTool
  tool_name "widget_lab"
  description "ActionMCP MCP Apps demo. Renders an interactive widget showing " \
              "the message you pass. Set fail:true to render the widget's error state."

  renders_ui "ui://views/widget-lab"

  property :message, type: "string", required: true, description: "Text to display in the widget"
  property :fail, type: "boolean", default: false, description: "Render the widget's error state instead of success"

  output_schema do
    property :ok, type: "boolean", required: true, description: "Whether the widget should show a success state"
    property :message, type: "string", required: true, description: "Message echoed into the widget"
    property :detail, type: "string", description: "Extra detail line (error text when ok is false)"
  end

  def perform
    if fail
      render text: "widget_lab: rendering error state"
      render structured: {
        ok: false,
        message: "Something went wrong",
        detail: "Simulated failure for message: #{message.inspect}"
      }
    else
      render text: "widget_lab: rendering '#{message}'"
      render structured: {
        ok: true,
        message: message,
        detail: "Rendered by ActionMCP at #{Time.current.iso8601}"
      }
    end
  end
end
