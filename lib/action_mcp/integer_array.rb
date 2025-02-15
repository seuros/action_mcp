# frozen_string_literal: true

module ActionMCP
  # This temporary naming extracted from MCPangea
  # If there is a better name, please suggest it or part of ActiveModel, open a PR
  class IntegerArray < ActiveModel::Type::Value
    def cast(value)
      Array(value).map(&:to_i) # Ensure all elements are integers
    end
  end
end
