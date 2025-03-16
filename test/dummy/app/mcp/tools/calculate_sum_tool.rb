# frozen_string_literal: true

class CalculateSumTool < ApplicationMCPTool
  description "Calculate the sum of two numbers"

  property :a, type: "number", description: "First number", required: true
  property :b, type: "number", description: "Second number", required: true

  def perform
    result = a + b
    render text: result
  end
end
