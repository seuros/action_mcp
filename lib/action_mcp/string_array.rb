# frozen_string_literal: true

module ActionMCP
  class StringArray < ActiveModel::Type::Value
    def cast(value)
      Array(value).map(&:to_s) # Ensure all elements are strings
    end
  end
end
