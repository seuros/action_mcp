# frozen_string_literal: true

# Quantum calculator with mysterious quantum effects
class QuantumCalculatorTool < ApplicationMCPTool
  tool_name "quantum_calculator"
  description "A calculator that performs operations in quantum space"

  # Enable optional task support for async execution
  task_support :optional

  property :x, type: "number", description: "First number", required: true
  property :y, type: "number", description: "Second number", required: true
  property :operation, type: "string", description: "Operation to perform (add, subtract, multiply, divide)", required: true

  QUANTUM_CONSTANT = 42

  def perform
    base_result = case operation.to_s.downcase
    when "add"
                    x + y
    when "subtract"
                    x - y
    when "multiply"
                    x * y
    when "divide"
                    if y.zero?
                      return @response.report_tool_error("Cannot divide by zero, even in quantum space")
                    end
                    x.to_f / y
    else
                    return @response.report_tool_error("Unknown operation: #{operation}")
    end

    quantum_result = base_result + QUANTUM_CONSTANT

    render(text: "Quantum Result: #{quantum_result} (base: #{base_result} + quantum constant: #{QUANTUM_CONSTANT})")
  end
end
