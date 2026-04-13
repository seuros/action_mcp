# frozen_string_literal: true

require "test_helper"

module ActionMCP
  module Server
    class ElicitationRequestTest < ActiveSupport::TestCase
      test "valid with correct schema" do
        request = ElicitationRequest.new(
          message: "What is your name?",
          requested_schema: {
            type: "object",
            properties: { name: { type: "string" } },
            required: [ "name" ]
          }
        )

        assert request.valid?
      end

      test "to_params builds correct wire format" do
        schema = { type: "object", properties: { name: { type: "string" } } }
        request = ElicitationRequest.new(message: "Name?", requested_schema: schema)

        params = request.to_params
        assert_equal "form", params[:mode]
        assert_equal "Name?", params[:message]
        assert_equal schema, params[:requestedSchema]
        assert_nil params[:_meta]
      end

      test "to_params includes _meta when present" do
        request = ElicitationRequest.new(
          message: "Name?",
          requested_schema: { type: "object", properties: { name: { type: "string" } } },
          _meta: { taskId: "task-1" }
        )

        assert_includes request.to_params, :_meta
      end

      test "invalid without message" do
        request = ElicitationRequest.new(
          requested_schema: { type: "object", properties: { name: { type: "string" } } }
        )

        assert_not request.valid?
        assert_includes request.errors[:message], "can't be blank"
      end

      test "invalid without requested_schema" do
        request = ElicitationRequest.new(message: "test")

        assert_not request.valid?
        assert_includes request.errors[:requested_schema], "can't be blank"
      end

      test "invalid when schema is not object type" do
        request = ElicitationRequest.new(
          message: "test",
          requested_schema: { type: "string" }
        )

        assert_not request.valid?
        assert request.errors[:requested_schema].any? { |e| e.include?("object type") }
      end

      test "invalid when schema has no properties" do
        request = ElicitationRequest.new(
          message: "test",
          requested_schema: { type: "object" }
        )

        assert_not request.valid?
        assert request.errors[:requested_schema].any? { |e| e.include?("properties") }
      end

      test "invalid with nested object property" do
        request = ElicitationRequest.new(
          message: "test",
          requested_schema: {
            type: "object",
            properties: { nested: { type: "object", properties: {} } }
          }
        )

        assert_not request.valid?
        assert request.errors[:requested_schema].any? { |e| e.include?("primitive type") }
      end

      test "valid with string enum property" do
        request = ElicitationRequest.new(
          message: "Pick",
          requested_schema: {
            type: "object",
            properties: { color: { type: "string", enum: %w[red green blue] } }
          }
        )

        assert request.valid?
      end

      test "invalid when string enum is not an array" do
        request = ElicitationRequest.new(
          message: "Pick",
          requested_schema: {
            type: "object",
            properties: { color: { type: "string", enum: "red" } }
          }
        )

        assert_not request.valid?
      end

      test "valid with enum array using items enum" do
        request = ElicitationRequest.new(
          message: "Pick colors",
          requested_schema: {
            type: "object",
            properties: {
              colors: { type: "array", items: { type: "string", enum: %w[red green] } }
            }
          }
        )

        assert request.valid?
      end

      test "valid with enum array using anyOf" do
        request = ElicitationRequest.new(
          message: "Pick colors",
          requested_schema: {
            type: "object",
            properties: {
              colors: {
                type: "array",
                items: { anyOf: [ { const: "#FF0000", title: "Red" } ] }
              }
            }
          }
        )

        assert request.valid?
      end

      test "invalid array without items schema" do
        request = ElicitationRequest.new(
          message: "Pick",
          requested_schema: {
            type: "object",
            properties: { colors: { type: "array" } }
          }
        )

        assert_not request.valid?
        assert request.errors[:requested_schema].any? { |e| e.include?("items schema") }
      end

      test "valid with number, integer, and boolean properties" do
        request = ElicitationRequest.new(
          message: "Settings",
          requested_schema: {
            type: "object",
            properties: {
              count: { type: "integer" },
              ratio: { type: "number" },
              enabled: { type: "boolean" }
            }
          }
        )

        assert request.valid?
      end

      test "assert_valid! raises ArgumentError on invalid" do
        request = ElicitationRequest.new(message: "test", requested_schema: { type: "string" })

        error = assert_raises(ArgumentError) { request.assert_valid! }
        assert_match(/object type/, error.message)
      end

      test "assert_valid! does not raise on valid" do
        request = ElicitationRequest.new(
          message: "Name?",
          requested_schema: { type: "object", properties: { name: { type: "string" } } }
        )

        assert_nothing_raised { request.assert_valid! }
      end

      # --- String-keyed schema support (JSON-parsed hashes) ---

      test "valid with string-keyed schema" do
        request = ElicitationRequest.new(
          message: "Name?",
          requested_schema: {
            "type" => "object",
            "properties" => { "name" => { "type" => "string" } }
          }
        )

        assert request.valid?
      end

      test "valid with mixed string and symbol keys in schema" do
        request = ElicitationRequest.new(
          message: "Pick",
          requested_schema: {
            "type" => "object",
            "properties" => { color: { type: "string", "enum" => %w[red green] } }
          }
        )

        assert request.valid?
      end

      test "rejects nested object even with string keys" do
        request = ElicitationRequest.new(
          message: "test",
          requested_schema: {
            "type" => "object",
            "properties" => { "nested" => { "type" => "object", "properties" => {} } }
          }
        )

        assert_not request.valid?
      end
    end
  end
end
