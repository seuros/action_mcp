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

  def resolve
    order = MockOrder.find_by(id: order_id)
    return unless order

    resource = ActionMCP::Resource.new(
      uri: "ecommerce://orders/#{order_id}",
      name: "Order #{order_id}",
      description: "Order information for order #{order_id}",
      mime_type: "application/json",
      size: order.to_json.length
    )
    # Convert the Order model to a resource
    resource
  end
end

class MockOrder
  def initialize(id:, customer_id:, total:)
    @id = id
    @customer_id = customer_id
    @total = total
  end

  def to_json
    { id: @id, customer_id: @customer_id, total: @total }.to_json
  end

  def self.find(id)
    MockOrder.new(id: id, customer_id: "123", total: 100)
  end
end
