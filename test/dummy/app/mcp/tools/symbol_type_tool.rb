# frozen_string_literal: true

class SymbolTypeTool < ApplicationMCPTool
  title "Symbol Type Tool"
  description "accepts number_a and number_b attributes"
  read_only
  idempotent
  property :number_a, type: :number, required: true
  property :number_b, type: "number", required: true

  def perform
    render text: (number_a + number_b).to_s
  end
end
