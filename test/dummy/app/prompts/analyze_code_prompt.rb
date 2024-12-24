# frozen_string_literal: true

class AnalyzeCodePrompt < ApplicationPrompt
  # Override the tool_name (otherwise we'd get "analyze-code")
  prompt_name "analyze-code"

  # Provide a user-facing description for your tool.
  description "Analyze code for potential improvements"

  # Configure arguments via the new DSL
  argument :language, description: "Programming language", default: "Ruby"
  argument :code, description: "Code to explain", required: true

  # Add validations (note: "Ruby" is not allowed per the validation)
  validates :language, inclusion: { in: %w[C Cobol FORTRAN] }
end
