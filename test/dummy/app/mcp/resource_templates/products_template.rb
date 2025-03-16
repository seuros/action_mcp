# frozen_string_literal: true

class ProductsTemplate < ApplicationMCPResTemplate
  description "Access product information"
  uri_template "ecommerce://products/{product_id}"
  mime_type "application/json"

  parameter :product_id,
            description: "Product identifier",
            required: true

  validates :product_id, format: { with: /\A\d+\z/, message: "must be a number" }

  def resolve
    product = MockProduct.find_by(id: product_id)
    return unless product

    resource = ActionMCP::Resource.new(
      uri: "ecommerce://products/#{product_id}",
      name: "Product #{product_id}",
      description: "Product information for product #{product_id}",
      mime_type: "application/json",
      size: product.to_json.length
    )
    # Convert the Product model to a resource
    resource
  end
end

class MockProduct
  def initialize(id:, name:, price:)
    @id = id
    @name = name
    @price = price
  end

  def to_json
    { id: @id, name: @name, price: @price }.to_json
  end

  def self.find(id)
    MockProduct.new(id: id, name: "Product #{id}", price: 9.99)
  end
end
