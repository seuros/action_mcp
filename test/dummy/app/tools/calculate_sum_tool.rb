# frozen_string_literal: true

class CalculateSumTool < ApplicationTool
  description "Calculate the sum of two numbers"

  property :a, type: "number", description: "First number", required: true
  property :b, type: "number", description: "Second number", required: true

  def call
    result = a + b
    render_text(result)
  end
end
