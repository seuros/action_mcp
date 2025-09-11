# frozen_string_literal: true

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
    # Log or prepare template if needed
  end

  after_resolve do |template|
    # Cleanup or logging if needed
  end

  around_resolve do |template, block|
    start_time = Time.current

    resource = block.call

    # Could add timing or success/failure logging here if needed

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
