# frozen_string_literal: true

# Tool for testing task-augmented execution (MCP 2025-11-25)
# Supports both sync and async execution modes
class AsyncCalculatorTool < ApplicationMCPTool
  tool_name "async_calculator"
  description "A calculator that supports async task-based execution"

  # Enable optional task support
  task_support :optional

  property :x, type: "number", description: "First number", required: true
  property :y, type: "number", description: "Second number", required: true
  property :operation, type: "string", description: "Operation to perform (add, subtract, multiply, divide)", required: true
  property :delay_ms, type: "integer", description: "Optional delay in milliseconds to simulate work", required: false

  def perform
    # Simulate some work if delay is specified
    if delay_ms && delay_ms > 0
      sleep(delay_ms / 1000.0)
    end

    result = case operation.to_s.downcase
    when "add"
               x + y
    when "subtract"
               x - y
    when "multiply"
               x * y
    when "divide"
               if y.zero?
                 return @response.report_tool_error("Cannot divide by zero")
               end
               x.to_f / y
    else
               return @response.report_tool_error("Unknown operation: #{operation}")
    end

    render(text: "Result: #{result}")
  end
end
