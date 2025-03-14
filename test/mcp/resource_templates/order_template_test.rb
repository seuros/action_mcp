# frozen_string_literal: true

require "test_helper"

class OrderTemplateTest < ActiveSupport::TestCase
  test "should not be abstract" do
    refute OrdersTemplate.abstract?
  end
  test "orders_template_to_template_hash" do
    template_hash = OrdersTemplate.to_h
    assert_equal "orders", template_hash[:name]
    assert_equal "ecommerce://orders/{order_id}", template_hash[:uriTemplate]

    assert_equal "Access order information", template_hash[:description]
    assert_equal "application/json", template_hash[:mimeType]
  end
end
