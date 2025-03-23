# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Client
    class CatalogTest < ActiveSupport::TestCase
      setup do
        @resource_data = [
          {
            "uri" => "file:///project/src/main.rs",
            "name" => "main.rs",
            "description" => "Primary application entry point",
            "mimeType" => "text/x-rust"
          },
          {
            "uri" => "file:///project/src/lib.rs",
            "name" => "lib.rs",
            "description" => "Library module definitions",
            "mimeType" => "text/x-rust"
          },
          {
            "uri" => "file:///project/README.md",
            "name" => "README.md",
            "description" => "Project documentation",
            "mimeType" => "text/markdown"
          }
        ]
        @catalog = Catalog.new(@resource_data)
      end

      test "initializes with resource data" do
        assert_equal 3, @catalog.size
      end

      test "returns all resources" do
        resources = @catalog.all
        assert_equal 3, resources.size
        assert_instance_of Catalog::Resource, resources.first
      end

      test "finds a resource by URI" do
        resource = @catalog.find_by_uri("file:///project/src/main.rs")
        assert_equal "main.rs", resource.name
        assert_equal "Primary application entry point", resource.description
      end

      test "returns nil when finding a nonexistent resource" do
        assert_nil @catalog.find_by_uri("nonexistent")
      end

      test "finds resources by name" do
        resources = @catalog.find_by_name("main.rs")
        assert_equal 1, resources.size
        assert_equal "file:///project/src/main.rs", resources.first.uri
      end

      test "finds resources by MIME type" do
        resources = @catalog.find_by_mime_type("text/x-rust")
        assert_equal 2, resources.size
        assert_includes resources.map(&:name), "main.rs"
        assert_includes resources.map(&:name), "lib.rs"
      end

      test "filters resources with a block" do
        readme_resources = @catalog.filter { |r| r.name.include?("README") }
        assert_equal 1, readme_resources.size
        assert_equal "README.md", readme_resources.first.name
      end

      test "returns all resource URIs" do
        expected = [
          "file:///project/src/main.rs",
          "file:///project/src/lib.rs",
          "file:///project/README.md"
        ]
        assert_equal expected, @catalog.uris
      end

      test "checks if catalog contains a URI" do
        assert @catalog.contains_uri?("file:///project/src/main.rs")
        refute @catalog.contains_uri?("nonexistent")
      end

      test "groups resources by MIME type" do
        groups = @catalog.group_by_mime_type
        assert_equal 2, groups.size
        assert_equal 2, groups["text/x-rust"].size
        assert_equal 1, groups["text/markdown"].size
      end

      test "searches resources by keyword" do
        results = @catalog.search("application")
        assert_equal 1, results.size
        assert_equal "main.rs", results.first.name
      end

      test "enumerates all resources" do
        names = []
        @catalog.each { |resource| names << resource.name }
        assert_equal [ "main.rs", "lib.rs", "README.md" ], names
      end

      test "resource gets file extension" do
        resource = @catalog.find_by_uri("file:///project/README.md")
        assert_equal "md", resource.extension
      end

      test "resource checks if it's a text file" do
        markdown = @catalog.find_by_uri("file:///project/README.md")
        assert markdown.text?
      end

      test "resource gets path from URI" do
        resource = @catalog.find_by_uri("file:///project/src/main.rs")
        assert_equal "/project/src/main.rs", resource.path
      end

      test "resource generates hash representation" do
        resource = @catalog.find_by_uri("file:///project/src/main.rs")
        hash = resource.to_h
        assert_equal "file:///project/src/main.rs", hash["uri"]
        assert_equal "main.rs", hash["name"]
        assert_equal "Primary application entry point", hash["description"]
        assert_equal "text/x-rust", hash["mimeType"]
      end
    end
  end
end
