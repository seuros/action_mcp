# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ResourceTemplateTest < ActiveSupport::TestCase
    def setup
      # Save original registered templates
      @original_templates = ResourceTemplate.registered_templates.dup
      # Clear for testing
      ResourceTemplate.instance_variable_set(:@registered_templates, [])
    end

    def teardown
      # Restore original registered templates
      ResourceTemplate.instance_variable_set(:@registered_templates, @original_templates)
    end

    # Helper method to create temporary classes that will be garbage collected
    def create_temp_template(options = {})
      Class.new(ResourceTemplate) do
        def self.name = "Test\#{SecureRandom.hex(6)}Template"
        # Set abstract first if specified
        abstract! if options[:abstract]

        uri_template options[:uri_template] if options[:uri_template]
        description options[:description] || "Test Resource"

        # Define name method to avoid anonymous class issues in error messages
        define_singleton_method(:name) { options[:name] } if options[:name]
      end
    end

    test "allows unique URI templates" do
      # Create temporary classes with unique templates
      create_temp_template(uri_template: "service://resource/{id}", name: "Template1")
      create_temp_template(uri_template: "service://other/{name}", name: "Template2")
      create_temp_template(uri_template: "different://resource/{id}", name: "Template3")

      assert_equal 3, ResourceTemplate.registered_templates.size
    end

    test "rejects identical URI templates" do
      # Create first template
      create_temp_template(uri_template: "service://resource/{id}", name: "Template1")

      # Attempt to create a duplicate
      error = assert_raises(ArgumentError) do
        create_temp_template(uri_template: "service://resource/{param}", name: "Template2")
      end

      assert_match(/URI template conflict detected/, error.message)
    end

    test "rejects ambiguous URI templates with swapped parameters" do
      # Create first template
      create_temp_template(uri_template: "service://{param1}/{param2}", name: "Template1")

      # Attempt to create one with swapped parameters
      error = assert_raises(ArgumentError) do
        create_temp_template(uri_template: "service://{other1}/{other2}", name: "Template2")
      end

      assert_match(/URI template conflict detected/, error.message)
    end

    test "allows templates with different parameter counts" do
      # Create first template
      create_temp_template(uri_template: "service://{param1}/{param2}", name: "Template1")

      # This should be allowed since it has a different structure
      create_temp_template(uri_template: "service://{param1}/{param2}/{param3}", name: "Template2")

      assert_equal 2, ResourceTemplate.registered_templates.size
    end

    test "allows templates with same parameters but different schema" do
      # Create first template
      create_temp_template(uri_template: "service1://{param1}/{param2}", name: "Template1")

      # This should be allowed since it has a different schema
      create_temp_template(uri_template: "service2://{param1}/{param2}", name: "Template2")

      assert_equal 2, ResourceTemplate.registered_templates.size
    end

    test "abstract templates are not registered" do
      # Create an abstract template - make sure abstract! is called before uri_template
      create_temp_template(abstract: true, uri_template: "service://abstract/{id}", name: "AbstractTemplate")

      assert_empty ResourceTemplate.registered_templates
    end
  end
end
