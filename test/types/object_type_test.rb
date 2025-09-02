# frozen_string_literal: true

require "test_helper"

class ObjectTypeTest < ActiveSupport::TestCase
  setup do
    @type = ActionMCP::Types::ObjectType.new
  end

  test "type method returns :object" do
    assert_equal :object, @type.type
  end

  test "preserves hash with mixed value types" do
    input = {
      "string" => "value",
      "number" => 42,
      "float" => 3.14,
      "boolean" => true,
      "null" => nil,
      "array" => [ 1, 2, 3 ],
      "nested" => { "key" => "value" }
    }
    assert_equal input, @type.cast(input)
  end

  test "does not throw error when input is not a Hash" do
    assert_equal 42, @type.cast(42)
    assert_equal false, @type.cast(false)
    assert_equal [ 1, 2, 3 ], @type.cast([ 1, 2, 3 ])
    assert_equal "a string", @type.cast("a string")
  end
end
