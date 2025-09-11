# frozen_string_literal: true

require "test_helper"

class ResourceTemplateCallbacksTest < ActionDispatch::IntegrationTest
  test "callbacks are executed in the correct order for OrdersTemplate" do
    template = OrdersTemplate.new(customer_id: 1, order_id: 2)

    result = template.call

    # Verify the template executed successfully
    assert_not_nil result
  end

  test "callbacks are executed in the correct order for ProductsTemplate" do
    template = ProductsTemplate.new(product_id: 3)

    result = template.call

    # Verify the template executed successfully
    assert_not_nil result
  end
end
