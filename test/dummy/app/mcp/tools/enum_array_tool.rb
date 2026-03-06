# frozen_string_literal: true

class EnumArrayTool < ApplicationMCPTool
  title "Enum Array Tool"
  description "accepts array_string attribute"
  read_only
  idempotent
  collection :fruits, type: "string", required: true, enum: [ "apple", "banana", "cherry" ], description: "An array of fruits"

  def perform
    render text: fruits.join(", ")
  end
end
