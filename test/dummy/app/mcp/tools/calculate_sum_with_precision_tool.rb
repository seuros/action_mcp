# frozen_string_literal: true

class CalculateSumWithPrecisionTool < CalculateSumTool
  description "Calculate the sum of two numbers with specified precision"

  # inherits properties :a and :b from CalculateSumTool
  property :precision, type: "number", description: "Decimal precision", required: true, default: 2
  property :unit, type: "string", description: "Unit of measurement", required: false

  def perform
    sum = (number1 + number2).round(precision)
    render text: sum
  end
end
