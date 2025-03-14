# frozen_string_literal: true

require "test_helper"

class ProductsTemplateTest < ActiveSupport::TestCase
  test "products_template_to_template_hash" do
    template_hash = ProductsTemplate.to_h
    assert_equal "products", template_hash[:name]
    assert_equal "ecommerce://products/{product_id}", template_hash[:uriTemplate]

    assert_equal "Access product information", template_hash[:description]
    assert_equal "application/json", template_hash[:mimeType]
  end
end
