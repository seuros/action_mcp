# frozen_string_literal: true

class NumericArrayTool < ApplicationMCPTool
  title "Numeric Array Tool"
  description "accepts array_number attribute"
  read_only
  idempotent
  collection :numbers, type: "number", required: true

  def perform
    render text: numbers.sum
  end
end
