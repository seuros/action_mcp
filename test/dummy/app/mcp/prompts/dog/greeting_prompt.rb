# frozen_string_literal: true

class Dog::GreetingPrompt < ApplicationMCPPrompt
  description "Generates a personalized greeting message for a dog"

  argument :name, description: "The name of the dog to greet", required: true
  argument :style, description: "Style of greeting", enum: %w[formal casual friendly], default: "friendly"

  def perform
    render text: "Please create a greeting for a dog named #{name}"

    render text: "I'd be happy to create a #{style} greeting for a dog named #{name}!", role: "assistant"

    render text: "The greeting should be in #{style} style."
  end
end
