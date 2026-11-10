# frozen_string_literal: true

require "test_helper"

class ActionMCP::ToolCollectionKeywordsTest < ActiveSupport::TestCase
  test "item keywords land on items and array keywords on the array" do
    labels = properties["labels"]

    assert_equal({ type: "string", enum: %w[bug feature docs] }, labels[:items])
    assert_equal 1, labels[:minItems]
    assert_equal 3, labels[:maxItems]
    assert labels[:uniqueItems]
    assert_nil labels[:enum]
  end

  test "snake_case keywords become JSON Schema keywords" do
    assert_equal({ type: "string", minLength: 2, maxLength: 4 }, properties["code"])
    assert_equal({ type: "number", multipleOf: 5, exclusiveMinimum: 0 }, properties["estimate"])
  end

  test "JSON Schema spelling is accepted as is" do
    assert_equal 2, properties["watchers"][:maxItems]
  end

  test "accepts items from the enum" do
    assert TriageTicketTool.from_wire(labels: %w[bug docs]).valid?
  end

  test "rejects items outside the enum" do
    tool = TriageTicketTool.from_wire(labels: %w[bug wontfix])

    refute tool.valid?
    assert_match(%r{/labels/1}, tool.errors.full_messages.join)
  end

  test "enforces array keywords" do
    refute TriageTicketTool.from_wire(labels: []).valid?
    refute TriageTicketTool.from_wire(labels: %w[bug bug]).valid?
    refute TriageTicketTool.from_wire(labels: %w[bug feature docs bug]).valid?
  end

  test "property enum is enforced by the input schema" do
    tool = TriageTicketTool.from_wire(labels: %w[bug], priority: "urgent")

    refute tool.valid?
    assert_match(%r{/priority}, tool.errors.full_messages.join)
  end

  private

  def properties
    TriageTicketTool.input_schema[:properties]
  end
end
