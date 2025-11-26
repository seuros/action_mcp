# frozen_string_literal: true

require "test_helper"

class QuantumCalculatorToolTest < ActiveSupport::TestCase
  test "adds 42 to addition result" do
    tool = QuantumCalculatorTool.new(x: 5, y: 3, operation: "add")
    response = tool.call

    assert_match(/Quantum Result: 50/, response.to_h[:content].first[:text]) # 5 + 3 + 42
    assert_match(/base: 8/, response.to_h[:content].first[:text])
  end

  test "adds 42 to subtraction result" do
    tool = QuantumCalculatorTool.new(x: 10, y: 4, operation: "subtract")
    response = tool.call

    assert_match(/Quantum Result: 48/, response.to_h[:content].first[:text]) # 10 - 4 + 42
    assert_match(/base: 6/, response.to_h[:content].first[:text])
  end

  test "adds 42 to multiplication result" do
    tool = QuantumCalculatorTool.new(x: 3, y: 7, operation: "multiply")
    response = tool.call

    assert_match(/Quantum Result: 63/, response.to_h[:content].first[:text]) # 3 * 7 + 42
    assert_match(/base: 21/, response.to_h[:content].first[:text])
  end

  test "adds 42 to division result" do
    tool = QuantumCalculatorTool.new(x: 20, y: 4, operation: "divide")
    response = tool.call

    assert_match(/Quantum Result: 47/, response.to_h[:content].first[:text]) # 20 / 4 + 42
    assert_match(/base: 5/, response.to_h[:content].first[:text])
  end

  test "returns tool execution error for division by zero" do
    tool = QuantumCalculatorTool.new(x: 10, y: 0, operation: "divide")
    response = tool.call
    result = response.to_h

    # MCP spec: tool execution errors return isError: true (not JSON-RPC error codes)
    assert result[:isError], "Expected isError: true for tool execution error"
    assert_match(/Cannot divide by zero/, result[:content].first[:text])
  end

  test "returns tool execution error for unknown operation" do
    tool = QuantumCalculatorTool.new(x: 5, y: 3, operation: "modulo")
    response = tool.call
    result = response.to_h

    # MCP spec: tool execution errors return isError: true (not JSON-RPC error codes)
    assert result[:isError], "Expected isError: true for tool execution error"
    assert_match(/Unknown operation: modulo/, result[:content].first[:text])
  end
end
