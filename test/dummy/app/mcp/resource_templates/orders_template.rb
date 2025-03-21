class OrdersTemplate < ApplicationMCPResTemplate
  description "Access order information"
  uri_template "ecommerce://customers/{customer_id}/orders/{order_id}"
  mime_type "application/json"

  parameter :customer_id,
            description: "Customer identifier",
            required: true
  parameter :order_id,
            description: "Order identifier",
            required: true

  # You can mutate the template object before resolving
  before_resolve do |template|
    logger.tagged("OrdersTemplate") { logger.info("Starting to resolve order: #{template.order_id} for customer: #{template.customer_id}") }
  end

  after_resolve do |template|
    logger.tagged("OrdersTemplate") { logger.info("Finished resolving order resource for order: #{template.order_id}") }
  end

  around_resolve do |template, block|
    start_time = Time.current
    logger.tagged("OrdersTemplate") { logger.info("Starting resolution for order: #{template.order_id}") }

    resource = block.call

    if resource
      logger.tagged("OrdersTemplate") { logger.info("Order #{template.order_id} resolved successfully in #{Time.current - start_time}s") }
    else
      logger.tagged("OrdersTemplate") { logger.info("Order #{template.order_id} not found") }
    end

    resource
  end

  def resolve
    order = MockOrder.find_by(id: order_id)
    return unless order

    ActionMCP::Resource.new(
      uri: "ecommerce://orders/#{order_id}",
      name: "Order #{order_id}",
      description: "Order information for order #{order_id}",
      mime_type: "application/json",
      size: order.to_json.length
    )
  end
end
