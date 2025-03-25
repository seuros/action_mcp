# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Client
    class BlueprintTest < ActiveSupport::TestCase
      setup do
        @template_data = [
          {
            "uriTemplate" => "file:///{path}",
            "name" => "File Access",
            "description" => "Access local files",
            "mimeType" => "application/octet-stream"
          },
          {
            "uriTemplate" => "db://{database}/{table}",
            "name" => "Database Table",
            "description" => "Access database tables",
            "mimeType" => "application/json"
          },
          {
            "uriTemplate" => "api://{endpoint}/{resource}/{id}",
            "name" => "API Resource",
            "description" => "Access API resources",
            "mimeType" => "application/json"
          }
        ]
        @blueprints = Blueprint.new(@template_data, nil)
      end

      test "initializes with template data" do
        assert_equal 3, @blueprints.size
      end

      test "returns all blueprints" do
        templates = @blueprints.all
        assert_equal 3, templates.size
        assert_instance_of Blueprint::ResourceTemplate, templates.first
      end

      test "finds a blueprint by pattern" do
        blueprint = @blueprints.find_by_pattern("file:///{path}")
        assert_equal "File Access", blueprint.name
        assert_equal "Access local files", blueprint.description
      end

      test "returns nil when finding a nonexistent blueprint" do
        assert_nil @blueprints.find_by_pattern("nonexistent")
      end

      test "finds blueprints by name" do
        templates = @blueprints.find_by_name("API Resource")
        assert_equal 1, templates.size
        assert_equal "api://{endpoint}/{resource}/{id}", templates.first.pattern
      end

      test "constructs a URI from a blueprint" do
        uri = @blueprints.construct("db://{database}/{table}", { database: "users", table: "profiles" })
        assert_equal "db://users/profiles", uri
      end

      test "raises error when constructing with missing parameters" do
        assert_raises(KeyError) do
          @blueprints.construct("api://{endpoint}/{resource}/{id}", { endpoint: "v1", resource: "users" })
        end
      end

      test "raises error when constructing from unknown blueprint" do
        assert_raises(ArgumentError) do
          @blueprints.construct("unknown://{pattern}", { pattern: "value" })
        end
      end

      test "filters blueprints with a block" do
        file_blueprints = @blueprints.filter { |b| b.protocol == "file" }
        assert_equal 1, file_blueprints.size
        assert_equal "file:///{path}", file_blueprints.first.pattern
      end

      test "checks if collection contains a blueprint" do
        assert @blueprints.contains?("file:///{path}")
        refute @blueprints.contains?("nonexistent")
      end

      test "groups blueprints by protocol" do
        groups = @blueprints.group_by_protocol
        assert_equal 3, groups.size
        assert_equal 1, groups["file"].size
        assert_equal 1, groups["db"].size
        assert_equal 1, groups["api"].size
      end

      test "enumerates all blueprints" do
        names = []
        @blueprints.each { |blueprint| names << blueprint.name }
        assert_equal [ "File Access", "Database Table", "API Resource" ], names
      end

      test "blueprint extracts variables from pattern" do
        blueprint = @blueprints.find_by_pattern("api://{endpoint}/{resource}/{id}")
        assert_equal %w[endpoint resource id], blueprint.variables
      end

      test "blueprint gets protocol from pattern" do
        blueprint = @blueprints.find_by_pattern("db://{database}/{table}")
        assert_equal "db", blueprint.protocol
      end

      test "blueprint constructs URI from parameters" do
        blueprint = @blueprints.find_by_pattern("file:///{path}")
        uri = blueprint.construct({ path: "logs/app.log" })
        assert_equal "file:///logs/app.log", uri
      end

      test "blueprint checks compatibility with parameters" do
        blueprint = @blueprints.find_by_pattern("api://{endpoint}/{resource}/{id}")
        assert blueprint.compatible_with?({ endpoint: "v1", resource: "users", id: "123" })
        refute blueprint.compatible_with?({ endpoint: "v1", resource: "users" })
      end

      test "blueprint generates hash representation" do
        blueprint = @blueprints.find_by_pattern("file:///{path}")
        hash = blueprint.to_h
        assert_equal "file:///{path}", hash["uriTemplate"]
        assert_equal "File Access", hash["name"]
        assert_equal "Access local files", hash["description"]
        assert_equal "application/octet-stream", hash["mimeType"]
      end
    end
  end
end
