# frozen_string_literal: true

module ActionMCP
  # Manages the collection of content objects for tool results
  class ToolResponse < BaseResponse
    attr_reader :contents, :structured_content

    delegate :empty?, :size, :each, :find, :map, to: :contents

    def initialize
      super
      @contents = []
      @structured_content = nil
    end

    # Add content to the response
    def add(content)
      @contents << content
      content # Return the content for chaining
    end

    # Set structured content for the response
    def set_structured_content(content)
      @structured_content = content
    end

    # Implementation of build_success_hash for ToolResponse
    def build_success_hash
      result = {
        content: @contents.map(&:to_h)
      }
      result[:structuredContent] = @structured_content if @structured_content
      result
    end

    # Implementation of compare_with_same_class for ToolResponse
    def compare_with_same_class(other)
      contents == other.contents && is_error == other.is_error && structured_content == other.structured_content
    end

    # Implementation of hash_components for ToolResponse
    def hash_components
      [ contents, is_error, structured_content ]
    end

    # Pretty print for better debugging
    def inspect
      parts = [ "content: #{contents.inspect}" ]
      parts << "structuredContent: #{structured_content.inspect}" if structured_content
      parts << "isError: #{is_error}"
      "#<#{self.class.name} #{parts.join(', ')}>"
    end
  end
end
