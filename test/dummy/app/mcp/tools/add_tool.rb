# frozen_string_literal: true

class AddTool < ArithmeticTool
  tool_name "add"
  description "Add two numbers together"
  # Inherits properties :x and :y from ArithmeticTool.

  def perform
    render text: x + y
  end
end
