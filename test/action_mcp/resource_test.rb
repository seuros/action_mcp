# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class ResourceTest < ActiveSupport::TestCase
    test "creates resource with all fields" do
      resource = Resource.new(
        uri: "file:///test.txt",
        name: "test.txt",
        title: "Test File",
        description: "A test file",
        mime_type: "text/plain",
        size: 42,
        annotations: { audience: [ "user" ] }
      )

      assert_equal "file:///test.txt", resource.uri
      assert_equal "test.txt", resource.name
      assert_equal "Test File", resource.title
      assert_equal "A test file", resource.description
      assert_equal "text/plain", resource.mime_type
      assert_equal 42, resource.size
      assert_equal({ audience: [ "user" ] }, resource.annotations)
    end

    test "creates resource with only required fields" do
      resource = Resource.new(uri: "file:///test.txt", name: "test.txt")

      assert_equal "file:///test.txt", resource.uri
      assert_equal "test.txt", resource.name
      assert_nil resource.title
      assert_nil resource.description
      assert_nil resource.mime_type
      assert_nil resource.size
      assert_nil resource.annotations
    end

    test "backward compatibility with existing callers" do
      # Existing code uses uri:, name:, description:, mime_type:, size:
      resource = Resource.new(
        uri: "ecommerce://products/1",
        name: "Product 1",
        description: "A product",
        mime_type: "application/json",
        size: 100
      )

      assert_equal "ecommerce://products/1", resource.uri
      assert_equal "Product 1", resource.name
      assert_equal "A product", resource.description
      assert_equal "application/json", resource.mime_type
      assert_equal 100, resource.size
    end

    test "to_h includes only present fields" do
      resource = Resource.new(uri: "file:///test.txt", name: "test.txt")
      hash = resource.to_h

      assert_equal({ uri: "file:///test.txt", name: "test.txt" }, hash)
    end

    test "to_h converts mime_type to mimeType" do
      resource = Resource.new(
        uri: "file:///test.txt",
        name: "test.txt",
        mime_type: "text/plain"
      )

      assert_equal "text/plain", resource.to_h[:mimeType]
      assert_nil resource.to_h[:mime_type]
    end

    test "to_h includes title and annotations when present" do
      resource = Resource.new(
        uri: "file:///test.txt",
        name: "test.txt",
        title: "Test File",
        annotations: { priority: 0.5 }
      )

      hash = resource.to_h
      assert_equal "Test File", hash[:title]
      assert_equal({ priority: 0.5 }, hash[:annotations])
    end

    test "equality comparison" do
      r1 = Resource.new(uri: "file:///a.txt", name: "a")
      r2 = Resource.new(uri: "file:///a.txt", name: "a")
      r3 = Resource.new(uri: "file:///b.txt", name: "b")

      assert_equal r1, r2
      refute_equal r1, r3
    end

    test "resources are frozen" do
      resource = Resource.new(uri: "file:///test.txt", name: "test.txt")
      assert resource.frozen?
    end

    test "to_json produces valid JSON" do
      resource = Resource.new(
        uri: "file:///test.txt",
        name: "test.txt",
        mime_type: "text/plain"
      )

      parsed = JSON.parse(resource.to_json)
      assert_equal "file:///test.txt", parsed["uri"]
      assert_equal "test.txt", parsed["name"]
      assert_equal "text/plain", parsed["mimeType"]
    end
  end
end
