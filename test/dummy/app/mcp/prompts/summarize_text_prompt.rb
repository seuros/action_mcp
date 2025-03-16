# frozen_string_literal: true

# A sample prompt class to demonstrate usage and testing
class SummarizeTextPrompt < ApplicationMCPPrompt
  prompt_name "summarize_text"
  description "Summarize a piece of text using a chosen method"

  # Arguments
  argument :text, description: "Text to summarize", required: true
  argument :style,
           description: "Summarization style",
           default: "concise",
           enum: %w[concise detailed]

  def perform
    # Perform the summarization logic here.
    # For demonstration, we'll just stub out a short or long summary.

    case style
    when "detailed"
      # Return a slightly more descriptive summary
      render text: "[DETAILED] Summarizing the following text in detail: #{text}"
    else
      # Return a short summary for demonstration
      render text: "[CONCISE] #{text.truncate(20)}"
    end
  end
end
