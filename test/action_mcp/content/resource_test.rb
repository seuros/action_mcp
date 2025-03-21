# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Content
    class ResourceTest < ActiveSupport::TestCase
      test "initializes with uri and mime_type" do
        resource = Resource.new("gemfile://test", "text/plain")

        assert_equal "gemfile://test", resource.uri
        assert_equal "text/plain", resource.mime_type
        assert_nil resource.text
        assert_nil resource.blob
        assert_equal "resource", resource.type
      end

      test "initializes with optional text" do
        resource = Resource.new("gemfile://test", "text/plain", text: "sample text")

        assert_equal "gemfile://test", resource.uri
        assert_equal "text/plain", resource.mime_type
        assert_equal "sample text", resource.text
        assert_nil resource.blob
      end

      test "initializes with optional blob" do
        blob = Base64.strict_encode64("sample blob")
        resource = Resource.new("gemfile://test", "application/octet-stream", blob: blob)

        assert_equal "gemfile://test", resource.uri
        assert_equal "application/octet-stream", resource.mime_type
        assert_nil resource.text
        assert_equal blob, resource.blob
      end

      test "initializes with gemfile json data" do
        gemfile_json = [
          { name: "debug", version: ">= 0", requirement: "~> 1.8" },
          { name: "brakeman", version: ">= 0", requirement: "~> 6.0" },
          { name: "foreman", version: ">= 0", requirement: "~> 0.87" }
        ].to_json

        resource = Resource.new("gemfile://test", "application/json", text: gemfile_json)

        assert_equal "gemfile://test", resource.uri
        assert_equal "application/json", resource.mime_type
        assert_equal gemfile_json, resource.text
        assert_nil resource.blob
      end

      test "#to_h returns correct hash with uri and mime_type" do
        resource = Resource.new("gemfile://test", "text/plain")
        expected = { uri: "gemfile://test", mimeType: "text/plain" }

        assert_equal expected, resource.to_h
      end

      test "#to_h includes text when present" do
        resource = Resource.new("gemfile://test", "text/plain", text: "sample text")
        expected = { uri: "gemfile://test", mimeType: "text/plain", text: "sample text" }

        assert_equal expected, resource.to_h
      end

      test "#to_h includes blob when present" do
        blob = Base64.strict_encode64("sample blob")
        resource = Resource.new("gemfile://test", "application/octet-stream", blob: blob)
        expected = { uri: "gemfile://test", mimeType: "application/octet-stream", blob: blob }

        assert_equal expected, resource.to_h
      end

      test "#to_h with gemfile json data" do
        gemfile_data = [
          { name: "debug", version: ">= 0", requirement: "~> 1.8" },
          { name: "brakeman", version: ">= 0", requirement: "~> 6.0" },
          { name: "foreman", version: ">= 0", requirement: "~> 0.87" }
        ]

        gemfile_json = gemfile_data.to_json
        resource = Resource.new("gemfile://test", "application/json", text: gemfile_json)

        expected = {
          uri: "gemfile://test",
          mimeType: "application/json",
          text: gemfile_json
        }

        assert_equal expected, resource.to_h

        # Verify the JSON can be parsed back correctly
        parsed_data = JSON.parse(resource.text)
        assert_equal gemfile_data.size, parsed_data.size
        assert_equal "debug", parsed_data[0]["name"]
        assert_equal "~> 1.8", parsed_data[0]["requirement"]
      end
    end
  end
end
