# frozen_string_literal: true

class EnumTool < ApplicationMCPTool
  title "Enum Tool"
  description "accepts enum attribute"
  read_only
  idempotent
  property :fruit, type: "string", required: true, enum: [ "apple", "banana", "cherry" ], description: "A fruit"

  def perform
    render text: fruit
  end
end
