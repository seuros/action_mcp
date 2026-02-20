# frozen_string_literal: true

module ActionMCP
  # Manages the collection of content objects for tool results
  class ToolResponse < BaseResponse
    attr_reader :contents, :structured_content, :tool_execution_error

    delegate :empty?, :size, :each, :find, :map, to: :contents

    def initialize
      super
      @contents = []
      @structured_content = nil
      @tool_execution_error = false  # Track if this is a tool execution error
    end

    # Add content to the response
    def add(content)
      @contents << content
      content # Return the content for chaining
    end

    # Set structured content for the response
    def set_structured_content(content)
      @structured_content = content

      if ActionMCP.configuration.include_serialized_structured_content_in_response
        @contents << {
          type: "text",
          text: content.to_json
        }
      end

      content
    end

    # Report a tool execution error (as opposed to protocol error)
    # This follows MCP spec for tool execution errors
    def report_tool_error(message)
      @tool_execution_error = true
      add(Content::Text.new(message))
    end

    def to_h(_options = nil)
      if @tool_execution_error
        result = {
          isError: true,
          content: @contents.map(&:to_h)
        }
        result[:structuredContent] = @structured_content if @structured_content
        result
      else
        super
      end
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
      contents == other.contents && is_error == other.is_error &&
        structured_content == other.structured_content &&
        tool_execution_error == other.tool_execution_error
    end

    # Implementation of hash_components for ToolResponse
    def hash_components
      [ contents, is_error, structured_content, tool_execution_error ]
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
