# frozen_string_literal: true

class FormatCodeTool < ApplicationTool
  # Force a specific name (else would default to "format-code")
  tool_name "format_source"
  description "Format source code according to a specific style"

  property :source_code, type: "string", description: "The code to be formatted", required: true
  property :language, type: "string", description: "Programming language", required: true
  property :style, type: "string", description: "Style or formatter rules"

  def call
    formatted_code = source_code.gsub(/\s+/, " ").strip
    render_text(formatted_code)
  end
end
