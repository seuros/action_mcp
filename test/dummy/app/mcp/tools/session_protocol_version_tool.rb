# frozen_string_literal: true

class SessionProtocolVersionTool < ApplicationMCPTool
  tool_name "session-protocol-version"
  description "Returns the MCP protocol version being used in the current session"

  def perform
    return render(text: "Error: No session context available") unless session

    protocol_version = session.protocol_version

    response = {
      protocol_version: protocol_version,
      codename: "The Task Master",
      session_id: session.id,
      supported_versions: ActionMCP::SUPPORTED_VERSIONS
    }

    render(text: JSON.pretty_generate(response))
  end
end
