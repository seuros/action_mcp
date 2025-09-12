# frozen_string_literal: true

class GreetingPrompt < ApplicationMCPPrompt
  description "Generates a personalized greeting message"

  include ActionMCP::Callbacks
  include ActionMCP::Instrumentation

  argument :name, description: "The name to greet", required: true
  argument :style, description: "Style of greeting", enum: %w[formal casual friendly], default: "friendly"

  before_perform do
    # Log callback execution if needed
  end

  around_perform do |_prompt, block|
    # Log around callback if needed
    block.call
  end

  after_perform do
    # Log after callback if needed
  end

  def perform
    render text: "Please create a greeting for #{name}"

    render text: "I'd be happy to create a #{style} greeting for #{name}!", role: "assistant"

    render text: "The greeting should be in #{style} style."
  end
end
