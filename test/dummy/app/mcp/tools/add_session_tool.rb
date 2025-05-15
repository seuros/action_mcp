# frozen_string_literal: true

# app/mcp/tools/add_session_tool.rb
class AddSessionTool < ApplicationMCPTool
  tool_name "add_session_tool"
  title "Add Session Tool"
  description "Add a tool to the current session's registry"
  destructive
  idempotent
  open_world

  property :tool_name,
           type: "string",
           description: "Name of the tool to add to this session",
           required: true

  def perform
    return render(text: "Error: No session context available") unless session

    if session.register_tool(tool_name)
      render(text: "✅ Tool '#{tool_name}' successfully added to session")

      # Show updated tool list
      updated_tools = session.registered_tools.map(&:tool_name)
      render(text: "📋 Session now has #{updated_tools.size} tools: #{updated_tools.join(', ')}")
    else
      render(text: "❌ Error: Tool '#{tool_name}' not found in server registry")
    end
  end
end
