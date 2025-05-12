# frozen_string_literal: true

# This class is now superseded by ValidatedFormatCodeTool
# Making it abstract to prevent registration in the tools registry
class FormatCodeTool < ApplicationMCPTool
  abstract_class = true

  # Force a specific name (else would default to "format-code")
  tool_name "format_source_legacy"
  description "Format source code according to a specific style"

  property :source_code, type: "string", description: "The code to be formatted", required: true
  property :language, type: "string", description: "Programming language", required: true
  property :style, type: "string", description: "Style or formatter rules"

  def perform
    formatted_code = source_code.gsub(/\s+/, " ").strip
    render text: formatted_code
  end
end
