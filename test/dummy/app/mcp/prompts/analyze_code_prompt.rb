# frozen_string_literal: true

class AnalyzeCodePrompt < ApplicationMCPPrompt
  # Provide a user-facing description for your tool.
  description "Analyze code for potential improvements"

  # Configure arguments via the new DSL
  argument :language,
           description: "Programming language",
           default: "Ruby",
           enum: %w[Ruby C Cobol FORTRAN]
  argument :code,
           description: "Code to explain",
           required: true

  def perform
    issue_url = "https://github.com/fake/repo/issues/#{rand(1000..9999)}"
    render text: "The code you provided is written in #{language} and looks great!"
  end
end
