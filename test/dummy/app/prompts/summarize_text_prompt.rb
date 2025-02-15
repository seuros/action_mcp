# frozen_string_literal: true

# A sample prompt class to demonstrate usage and testing
class SummarizeTextPrompt < ApplicationPrompt
  prompt_name "summarize-text"
  description "Summarize a piece of text using a chosen method"

  # Arguments
  argument :text, description: "Text to summarize", required: true
  argument :style, description: "Summarization style", default: "concise"

  # Validation: style must be a known style
  validates :style, inclusion: { in: %w[concise detailed] }

  def call
    # Perform the summarization logic here.
    # For demonstration, we'll just stub out a short or long summary.

    case style
    when "concise"
      # Return a short summary for demonstration
      { summary: "[CONCISE] #{text.truncate(20)}" }
    else
      # Return a slightly more descriptive summary
      { summary: "[DETAILED] Summarizing the following text in detail: #{text}" }
    end
  end
end
