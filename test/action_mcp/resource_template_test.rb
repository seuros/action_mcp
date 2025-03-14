# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ResourceTemplateTest < ActiveSupport::TestCase
    test "orders_template_retrieve" do
      resource = OrdersTemplate.retrieve(order_id: "123")
      assert_equal "ecommerce://orders/123", resource.uri
      assert_equal "Order 123", resource.name
      assert_equal "Order information for order 123", resource.description
      assert_equal "application/json", resource.mime_type
      assert_equal '{"id":"123","customer_id":"123","total":100}'.length, resource.size
    end
  end
end
