# frozen_string_literal: true

require "test_helper"

class ActionMCP::ToolCollectionKeywordsTest < ActiveSupport::TestCase
  FruitBasket = Class.new(ActionMCP::Tool) do
    tool_name "collection_keywords_fruit_basket"
    description "Collection with item and array keywords"
    collection :fruits, type: "string", enum: %w[apple banana cherry], minItems: 1, maxItems: 3, uniqueItems: true
    property :mood, type: "string", enum: %w[hungry full]

    def perform
      render text: fruits.join(", ")
    end
  end

  test "item keywords land on items and array keywords on the array" do
    fruits = FruitBasket.input_schema[:properties]["fruits"]

    assert_equal({ type: "string", enum: %w[apple banana cherry] }, fruits[:items])
    assert_equal 1, fruits[:minItems]
    assert_equal 3, fruits[:maxItems]
    assert fruits[:uniqueItems]
    assert_nil fruits[:enum]
  end

  test "accepts items from the enum" do
    assert FruitBasket.from_wire(fruits: %w[apple cherry]).valid?
  end

  test "rejects items outside the enum" do
    tool = FruitBasket.from_wire(fruits: %w[apple durian])

    refute tool.valid?
    assert_match(%r{/fruits/1}, tool.errors.full_messages.join)
  end

  test "enforces array keywords" do
    refute FruitBasket.from_wire(fruits: []).valid?
    refute FruitBasket.from_wire(fruits: %w[apple apple]).valid?
    refute FruitBasket.from_wire(fruits: %w[apple banana cherry apple]).valid?
  end

  test "property enum is enforced by the input schema" do
    tool = FruitBasket.from_wire(fruits: %w[apple], mood: "angry")

    refute tool.valid?
    assert_match(%r{/mood}, tool.errors.full_messages.join)
  end
end
