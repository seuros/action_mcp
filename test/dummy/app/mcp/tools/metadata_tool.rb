# frozen_string_literal: true

class MetadataTool < ApplicationMCPTool
  tool_name "metadata"
  description "Accepts an object property"

  property :name, type: "string", description: "Resource name", required: true
  property :attributes, type: "object", description: "Arbitrary key-value attributes"

  def perform
    render json: { name: name, attributes: attributes }
  end
end
