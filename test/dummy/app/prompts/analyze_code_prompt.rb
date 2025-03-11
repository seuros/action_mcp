# frozen_string_literal: true

class AnalyzeCodePrompt < ApplicationPrompt
  # Provide a user-facing description for your tool.
  description "Analyze code for potential improvements"

  # Configure arguments via the new DSL
  argument :language, description: "Programming language", default: "Ruby"
  argument :code, description: "Code to explain", required: true

  # Add validations (note: "Ruby" is not allowed per the validation)
  validates :language, inclusion: { in: %w[Ruby C Cobol FORTRAN] }

  def call
    render_text("The code you provided is written in #{language} and looks great!")
  end
end
