# frozen_string_literal: true

class CalculateSumWithPrecisionTool < CalculateSumTool
  tool_name "calculate_sum_with_precision"
  description "Calculate the sum of two numbers with specified precision"

  property :precision, type: "integer", description: "Decimal precision", required: false, default: 2
end
