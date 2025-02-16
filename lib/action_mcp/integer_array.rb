# frozen_string_literal: true

module ActionMCP
  # This temporary naming extracted from MCPangea
  # If there is a better name, please suggest it or part of ActiveModel, open a PR
  #
  # Custom type for handling arrays of integers in ActiveModel.
  class IntegerArray < ActiveModel::Type::Value
    # Casts the given value to an array of integers.
    #
    # @param value [Object] The value to cast.
    # @return [Array<Integer>] The array of integers.
    def cast(value)
      Array(value).map(&:to_i) # Ensure all elements are integers
    end
  end
end
