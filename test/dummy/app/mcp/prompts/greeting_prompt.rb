# frozen_string_literal: true

class GreetingPrompt < ApplicationMCPPrompt
  description "Generates a personalized greeting message"

  argument :name, description: "The name to greet", required: true
  argument :style, description: "Style of greeting", enum: %w[formal casual friendly], default: "friendly"

  def perform
    render text: "Please create a greeting for #{name}"

    render text: "I'd be happy to create a #{style} greeting for #{name}!", role: "assistant"

    render text: "The greeting should be in #{style} style."
  end
end
