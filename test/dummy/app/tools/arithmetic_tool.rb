# frozen_string_literal: true

class ArithmeticTool < ApplicationTool
  abstract!  # Mark this as abstract so it is not directly registered as a concrete tool.

  description "Abstract arithmetic tool"

  property :x, type: "number", description: "First operand", required: true
  property :y, type: "number", description: "Second operand", required: true
end
