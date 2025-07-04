# frozen_string_literal: true

class SessionProtocolVersionTool < ApplicationMCPTool
  tool_name "session-protocol-version"
  description "Returns the MCP protocol version being used in the current session"

  def perform
    return render(text: "Error: No session context available") unless session

    protocol_version = session.protocol_version

    # Determine the protocol codename based on version
    codename = case protocol_version
    when "2025-06-18"
                 "Dr. Identity McBouncer"
    when "2025-03-26"
                 "The Persistent Negotiator"
    when "2024-11-05"
                 "The Original Voyager"
    else
                 "Unknown Protocol"
    end

    response = {
      protocol_version: protocol_version,
      codename: codename,
      session_id: session.id,
      supported_versions: ActionMCP::SUPPORTED_VERSIONS
    }

    render(text: JSON.pretty_generate(response))
  end
end
