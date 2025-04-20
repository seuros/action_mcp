# frozen_string_literal: true

class NumericArrayTool < ApplicationMCPTool
  description "accepts array_number attribute"
  collection :numbers, type: "number", required: true

  def perform
    render text: numbers.sum
  end
end
