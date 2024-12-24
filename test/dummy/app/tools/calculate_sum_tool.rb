# frozen_string_literal: true

class CalculateSumTool < ApplicationTool
  tool_name "calculate_sum"
  description "Calculate the sum of two numbers"

  property :a, type: "number", description: "First number", required: true
  property :b, type: "number", description: "Second number", required: true
end
