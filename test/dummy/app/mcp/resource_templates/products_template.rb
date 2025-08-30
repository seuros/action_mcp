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
    logger.tagged("ProductsTemplate") { logger.info("Starting to resolve product: #{template.product_id}") }
  end

  after_resolve do |template|
    logger.tagged("ProductsTemplate") do
      logger.info("Finished resolving product resource for product: #{template.product_id}")
    end
  end

  around_resolve do |template, block|
    start_time = Time.current
    logger.tagged("ProductsTemplate") { logger.info("Starting resolution for product: #{template.product_id}") }

    response = block.call

    if response.success?
      logger.tagged("ProductsTemplate") do
        logger.info("Product #{template.product_id} resolved successfully in #{Time.current - start_time}s")
      end
    else
      logger.tagged("ProductsTemplate") { logger.info("Product #{template.product_id} not found") }
    end

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
