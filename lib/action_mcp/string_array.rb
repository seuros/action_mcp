# frozen_string_literal: true

module ActionMCP
  # Custom type for handling arrays of strings in ActiveModel.
  class StringArray < ActiveModel::Type::Value
    # Casts the given value to an array of strings.
    #
    # @param value [Object] The value to cast.
    # @return [Array<String>] The array of strings.
    def cast(value)
      Array(value).map(&:to_s) # Ensure all elements are strings
    end
  end
end
