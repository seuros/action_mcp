# frozen_string_literal: true

require "test_helper"

class SymbolTypeToolTest < ActiveSupport::TestCase
  include ActionMCP::TestHelper

  setup do
    @tool = SymbolTypeTool.new
  end

  test "tool is registered and available" do
    assert ActionMCP.tools.key?("symbol_type")
    assert_equal SymbolTypeTool, ActionMCP.tools["symbol_type"]
  end

  test "tool metadata is correct" do
    assert_equal "Symbol Type Tool", SymbolTypeTool.title
    assert_equal "accepts number_a and number_b attributes", SymbolTypeTool.description
    assert SymbolTypeTool.read_only?
    assert SymbolTypeTool.idempotent?
  end

  test "validates presence of required properties" do
    tool = SymbolTypeTool.new
    assert_not tool.valid?
    assert_includes tool.errors[:number_a], "can't be blank"
    assert_includes tool.errors[:number_b], "can't be blank"
  end

  test "validates numericality of properties" do
    assert_raises(ArgumentError, /number_a must be a number/) {
      SymbolTypeTool.new(number_a: "not a number")
    }

    assert_raises(ArgumentError, /number_b must be a number/) {
      SymbolTypeTool.new(number_a: "not a number")
    }
  end
end
