# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ResourceTemplateListTest < ActiveSupport::TestCase
    def setup
      @original_templates = ResourceTemplate.registered_templates.dup
      ResourceTemplate.instance_variable_set(:@registered_templates, [])
    end

    def teardown
      ResourceTemplate.instance_variable_set(:@registered_templates, @original_templates)
    end

    test "default list returns empty array" do
      template = Class.new(ResourceTemplate) do
        def self.name = "EmptyTemplate"
        uri_template "test://items/{id}"
        description "Test"
      end

      assert_equal [], template.list
      assert_equal [], template.list(session: nil)
    end

    test "lists_resources? returns false for base class" do
      template = Class.new(ResourceTemplate) do
        def self.name = "NoListTemplate"
        uri_template "test://things/{id}"
        description "No list"
      end

      refute template.lists_resources?
    end

    test "lists_resources? returns true when list is overridden" do
      template = Class.new(ResourceTemplate) do
        def self.name = "WithListTemplate"
        uri_template "test://widgets/{id}"
        description "With list"

        def self.list(session: nil)
          [ build_resource(uri: "test://widgets/1", name: "Widget 1") ]
        end
      end

      assert template.lists_resources?
    end

    test "build_resource creates Resource with template defaults" do
      template = Class.new(ResourceTemplate) do
        def self.name = "DefaultsTemplate"
        uri_template "test://docs/{id}"
        description "Documentation resource"
        mime_type "text/markdown"
      end

      resource = template.build_resource(uri: "test://docs/1", name: "Doc 1")

      assert_instance_of Resource, resource
      assert_equal "test://docs/1", resource.uri
      assert_equal "Doc 1", resource.name
      assert_equal "Documentation resource", resource.description
      assert_equal "text/markdown", resource.mime_type
    end

    test "build_resource allows overriding defaults" do
      template = Class.new(ResourceTemplate) do
        def self.name = "OverrideTemplate"
        uri_template "test://files/{path}"
        description "Default desc"
        mime_type "text/plain"
      end

      resource = template.build_resource(
        uri: "test://files/readme",
        name: "README",
        description: "Custom desc",
        mime_type: "text/markdown",
        title: "The README",
        size: 1024,
        annotations: { priority: 1.0 }
      )

      assert_equal "Custom desc", resource.description
      assert_equal "text/markdown", resource.mime_type
      assert_equal "The README", resource.title
      assert_equal 1024, resource.size
      assert_equal({ priority: 1.0 }, resource.annotations)
    end

    test "readable_uri? returns true for valid URI" do
      template = Class.new(ResourceTemplate) do
        def self.name = "ReadableTemplate"
        uri_template "test://items/{id}"
        description "Test"
        parameter :id, description: "ID", required: true
      end

      assert template.readable_uri?("test://items/123")
    end

    test "readable_uri? returns false for non-matching URI" do
      template = Class.new(ResourceTemplate) do
        def self.name = "NonMatchTemplate"
        uri_template "test://items/{id}"
        description "Test"
        parameter :id, description: "ID", required: true
      end

      refute template.readable_uri?("other://items/123")
      refute template.readable_uri?("test://different/123")
    end

    test "readable_uri? returns false for mismatched URI on no-param template" do
      template = Class.new(ResourceTemplate) do
        def self.name = "StaticTemplate"
        uri_template "test://status"
        description "Static status endpoint"
      end

      assert template.readable_uri?("test://status")
      refute template.readable_uri?("test://other/path")
      refute template.readable_uri?("other://status")
    end
  end
end
