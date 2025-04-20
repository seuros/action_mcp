# frozen_string_literal: true

class BoomTool < ApplicationMCPTool
  # This tool exists purely for negative‑path testing:
  # calling it will always raise, so ToolResponse should
  # come back with isError: true and code -32603 (:internal_error)

  tool_name    "boom"
  description  "Intentionally raises an exception to exercise error handling"

  property :message,
           type: "string",
           description: "Custom exception message",
           required: false,
           default: "Boom! Simulated failure."

  def perform
    raise StandardError, message
  end
end
