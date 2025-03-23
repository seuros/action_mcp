# frozen_string_literal: true

module ActionMCP
  # Manages the collection of content objects for tool results
  class ToolResponse < BaseResponse
    attr_reader :contents

    delegate :empty?, :size, :each, :find, :map, to: :contents

    def initialize
      super
      @contents = []
    end

    # Add content to the response
    def add(content)
      @contents << content
      content # Return the content for chaining
    end

    # Implementation of build_success_hash for ToolResponse
    def build_success_hash
      {
        content: @contents.map(&:to_h)
      }
    end

    # Implementation of compare_with_same_class for ToolResponse
    def compare_with_same_class(other)
      contents == other.contents && is_error == other.is_error
    end

    # Implementation of hash_components for ToolResponse
    def hash_components
      [ contents, is_error ]
    end

    # Pretty print for better debugging
    def inspect
      "#<#{self.class.name} content: #{contents.inspect}, isError: #{is_error}>"
    end
  end
end
