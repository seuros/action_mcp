# frozen_string_literal: true

class Alien::GreetingPrompt < ApplicationMCPPrompt
  prompt_name "alien_greeting"
  description "Generates a personalized greeting message for a alien"

  argument :name, description: "The name of the alien to greet", required: true
  argument :style, description: "Style of greeting", enum: %w[formal casual friendly], default: "friendly"

  def perform
    render text: "Please create a greeting for an alien named #{name}"

    render text: "I'd be happy to create a #{style} greeting for a alien named #{name}!", role: "assistant"

    render text: "The greeting should be in #{style} style."
  end
end
