# frozen_string_literal: true

require "test_helper"

class OrderTemplateTest < ActiveSupport::TestCase
  test "should not be abstract" do
    refute OrdersTemplate.abstract?
  end

  test "should set mime type" do
    assert_equal "application/json", OrdersTemplate.mime_type
  end

  test "orders_template_to_template_hash" do
    template_hash = OrdersTemplate.to_h
    assert_equal "orders", template_hash[:name]
    assert_equal "ecommerce://customers/{customer_id}/orders/{order_id}", template_hash[:uriTemplate]

    assert_equal "Access order information", template_hash[:description]
    assert_equal "application/json", template_hash[:mimeType]
  end

  # New tests for URI parsing functionality
  test "parses order_id from uri" do
    template = OrdersTemplate.process("ecommerce://customers/032/orders/123")

    assert_equal "032", template.customer_id
    assert_equal "123", template.order_id
  end

  test "handles missing parameters in orders uri" do
    template = OrdersTemplate.new
    assert_not template.valid?

    template = OrdersTemplate.process("ecommerce://orders/")
    assert_not template.valid?
  end
end
