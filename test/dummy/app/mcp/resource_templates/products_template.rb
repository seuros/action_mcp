# frozen_string_literal: true

class ProductsTemplate < ApplicationMCPResTemplate
  description "Access product information"
  uri_template "ecommerce://products/{product_id}"
  mime_type "application/json"

  parameter :product_id,
            description: "Product identifier",
            required: true

  # You can mutate the template object before resolving
  before_resolve do |template|
    # Log or prepare template if needed
  end

  after_resolve do |template|
    # Cleanup or logging if needed
  end

  around_resolve do |template, block|
    start_time = Time.current

    response = block.call

    # Could add timing or success/failure logging here if needed

    response
  end

  def resolve
    product = MockProduct.find_by(id: product_id)
    return unless product

    ActionMCP::Resource.new(
      uri: "ecommerce://products/#{product_id}",
      name: "Product #{product_id}",
      description: "Product information for product #{product_id}",
      mime_type: "application/json",
      size: product.to_json.length
    )
  end
end
