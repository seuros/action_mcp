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

  # Enumerate concrete products for resources/list
  def self.list(session: nil)
    # Return a few well-known products as static resources
    [ 1, 2, 3 ].map do |id|
      build_resource(
        uri: "ecommerce://products/#{id}",
        name: "Product #{id}",
        title: "Product ##{id}",
        description: "Product information for product #{id}"
      )
    end
  end

  def resolve
    product = MockProduct.find_by(id: product_id)
    return unless product

    data = { id: product.id, name: "Product #{product_id}" }

    ActionMCP::Content::Resource.new(
      "ecommerce://products/#{product_id}",
      "application/json",
      text: data.to_json
    )
  end
end
