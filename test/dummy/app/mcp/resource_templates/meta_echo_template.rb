# frozen_string_literal: true

class MetaEchoTemplate < ApplicationMCPResTemplate
  description "Echo resource that includes _meta in its content"
  uri_template "meta-echo://item/{id}"
  mime_type "application/json"

  parameter :id, description: "Item identifier", required: true

  def resolve
    ActionMCP::Content::Resource.new(
      "meta-echo://item/#{id}",
      "application/json",
      text: "{}",
      meta: { ui: { prefersBorder: true } }
    )
  end
end
