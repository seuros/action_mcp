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

  # New tests for URI parsing functionality
  test "parses product_id from uri" do
    template = ProductsTemplate.process("ecommerce://products/456")

    assert_equal "456", template.product_id
  end

  test "handles invalid uri format" do
    template = ProductsTemplate.process("ecommerce://invalid/path")
    assert_not template.valid?
  end

  test "method missing provides access to parameters" do
    template = ProductsTemplate.process("ecommerce://products/789")

    assert_equal "789", template.product_id
    assert_respond_to template, :product_id

    assert_raises(NoMethodError) do
      template.invalid_param
    end
  end
end
