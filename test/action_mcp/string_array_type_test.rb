# frozen_string_literal: true

require "test_helper"

class StringArrayTypeTest < ActiveSupport::TestCase
  test "StringArray casts scalars & mixed input to array of strings" do
    type = ActionMCP::StringArray.new

    assert_equal [ "a" ], type.cast("a")
    assert_equal %w[1 2 3],        type.cast([ 1, 2, 3 ])
    assert_equal [],               type.cast(nil)
  end
end

class NumericArrayToolTest < ActiveSupport::TestCase
  test "collection :numbers coerces strings to floats" do
    resp = NumericArrayTool.new(numbers: %w[1 2 3]).call
    assert_equal "6", resp.contents.first.text
  end
end
