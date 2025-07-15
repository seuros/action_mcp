# frozen_string_literal: true

class ConsentRequiredTool < ApplicationMCPTool
  tool_name "consent_required"
  description "A tool that requires consent to execute"

  property :input, type: "string", description: "Input string", required: true

  requires_consent!

  def perform
    render text: "Processed input: #{input}"
  end
end
