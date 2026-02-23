# frozen_string_literal: true

require "test_helper"

class ResourceTemplateErrorHandlingTest < ActiveSupport::TestCase
  # Test template for parameter validation errors
  class TestValidationTemplate < ApplicationMCPResTemplate
    description "Test template for validation errors"
    uri_template "test://validation/{required_param}"

    parameter :required_param,
              description: "Required parameter",
              required: true

    def resolve
      "Test resource with param: #{required_param}"
    end
  end

  # Test template for not found errors
  class TestNotFoundTemplate < ApplicationMCPResTemplate
    description "Test template for not found errors"
    uri_template "test://notfound/{item_id}"

    parameter :item_id,
              description: "Item ID",
              required: true

    def resolve
      return nil if item_id == "missing"

      "Found item: #{item_id}"
    end
  end

  # Test template for internal errors
  class TestInternalErrorTemplate < ApplicationMCPResTemplate
    description "Test template for internal errors"
    uri_template "test://error/{error_type}"

    parameter :error_type,
              description: "Type of error to trigger",
              required: true

    def resolve
      raise StandardError, "Simulated error: #{error_type}"
    end
  end

  def test_parameter_validation_error_response
    template = TestValidationTemplate.new(required_param: "")
    response = template.call

    assert response.error?
    assert_equal(-32_602, response.to_h[:code])
    assert_match(/Required parameters missing/, response.to_h[:message])
  end

  def test_template_not_found_error_response
    template = TestNotFoundTemplate.new(item_id: "missing")
    response = template.call

    assert response.error?
    assert_equal(-32_002, response.to_h[:code])
    assert_equal "Resource not found", response.to_h[:message]
  end

  def test_internal_error_response
    template = TestInternalErrorTemplate.new(error_type: "test")
    response = template.call

    assert response.error?
    assert_equal(-32_603, response.to_h[:code])
    assert_match(/Resource resolution failed/, response.to_h[:message])
  end

  def test_successful_response
    template = TestNotFoundTemplate.new(item_id: "exists")
    response = template.call

    assert response.success?
    assert_equal 1, response.contents.size
    assert_equal "Found item: exists", response.contents.first
  end

  def test_successful_response_with_valid_parameters
    template = TestValidationTemplate.new(required_param: "valid")
    response = template.call

    assert response.success?
    assert_equal 1, response.contents.size
    assert_equal "Test resource with param: valid", response.contents.first
  end
end
