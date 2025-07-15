# frozen_string_literal: true

require "test_helper"

class FloatArrayTypeTest < ActiveSupport::TestCase
  setup do
    @type = ActionMCP::Types::FloatArrayType.new
  end

  test "type name is float_array" do
    assert_equal :float_array, @type.type
  end

  test "casts integer array to float array" do
    result = @type.cast([ 1, 2, 3 ])
    assert_equal [ 1.0, 2.0, 3.0 ], result
    assert(result.all? { |n| n.is_a?(Float) })
  end

  test "preserves float array" do
    result = @type.cast([ 1.5, 2.7, 3.14 ])
    assert_equal [ 1.5, 2.7, 3.14 ], result
  end

  test "casts mixed numeric types" do
    result = @type.cast([ 1, 2.5, 3, 4.75 ])
    assert_equal [ 1.0, 2.5, 3.0, 4.75 ], result
  end

  test "casts string numbers to floats" do
    result = @type.cast([ "1", "2.5", "-3.14", "0" ])
    assert_equal [ 1.0, 2.5, -3.14, 0.0 ], result
  end

  test "handles invalid strings by filtering them out" do
    result = @type.cast([ "1", "invalid", "2.5", "not a number", "3" ])
    assert_equal [ 1.0, 2.5, 3.0 ], result
  end

  test "handles nil by returning empty array" do
    result = @type.cast(nil)
    assert_equal [], result
  end

  test "handles empty array" do
    result = @type.cast([])
    assert_equal [], result
  end

  test "filters out nil values in array" do
    result = @type.cast([ 1, nil, 2, nil, 3 ])
    assert_equal [ 1.0, 2.0, 3.0 ], result
  end

  test "handles non-array input by wrapping in array" do
    result = @type.cast(42)
    assert_equal [ 42.0 ], result

    result = @type.cast("3.14")
    assert_equal [ 3.14 ], result
  end

  test "serialize returns the same as cast" do
    input = [ 1, 2.5, 3 ]
    assert_equal @type.cast(input), @type.serialize(input)
  end

  test "deserialize handles JSON string" do
    json_string = "[1, 2.5, 3]"
    result = @type.deserialize(json_string)
    assert_equal [ 1.0, 2.5, 3.0 ], result
  end

  test "deserialize handles already parsed array" do
    result = @type.deserialize([ 1, 2, 3 ])
    assert_equal [ 1.0, 2.0, 3.0 ], result
  end

  test "deserialize handles invalid JSON" do
    result = @type.deserialize("not json")
    assert_equal [], result
  end

  test "deserialize handles nil" do
    result = @type.deserialize(nil)
    assert_equal [], result
  end

  test "handles BigDecimal values" do
    result = @type.cast([ BigDecimal("1.5"), BigDecimal("2.7") ])
    assert_equal [ 1.5, 2.7 ], result
  end

  test "handles Rational values" do
    result = @type.cast([ Rational(3, 2), Rational(5, 4) ])
    assert_equal [ 1.5, 1.25 ], result
  end

  test "handles scientific notation strings" do
    result = @type.cast([ "1e2", "3.14e-2", "2.5e+3" ])
    assert_equal [ 100.0, 0.0314, 2500.0 ], result
  end

  test "handles infinity and NaN" do
    result = @type.cast([ "Infinity", "-Infinity", "NaN" ])
    assert_equal [ Float::INFINITY, -Float::INFINITY, Float::NAN ], result

    # NaN requires special comparison
    assert_equal Float::INFINITY, result[0]
    assert_equal(-Float::INFINITY, result[1])
    assert result[2].nan?
  end
end
