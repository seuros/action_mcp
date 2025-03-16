# frozen_string_literal: true

module ActionMCP
  # Manages the collection of content objects for tool results
  class ToolResponse
    include Enumerable

    attr_reader :contents, :is_error

    delegate :empty?, :size, :each, :find, :map, to: :contents

    def initialize(is_error: false)
      @contents = []
      @is_error = is_error
    end

    # Add content to the response
    def add(content)
      @contents << content
      content # Return the content for chaining
    end

    # Mark response as error
    def mark_as_error!
      @is_error = true
      self
    end

    # Convert to hash format expected by MCP protocol
    def as_json(options = nil)
      {
        content: @contents.map { |c| c.as_json(options) },
        isError: @is_error
      }.compact
    end

    # Alias to_h to as_json for consistency
    alias_method :to_h, :as_json

    # Handle to_json directly
    def to_json(options = nil)
      as_json(options).to_json
    end

    # Compare with hash for easier testing
    # This allows assertions like: assert_equal({content: [...], isError: false}, tool_response)
    def ==(other)
      case other
      when Hash
        # Compare our hash representation with the other hash
        # Use deep symbolization to handle both string and symbol keys
        to_h.deep_symbolize_keys == other.deep_symbolize_keys
      when ToolResponse
        # Direct comparison with another ToolResponse
        contents == other.contents && is_error == other.is_error
      else
        super
      end
    end

    # Implement eql? for hash key comparison
    def eql?(other)
      self == other
    end

    # Implement hash method for hash key usage
    def hash
      [ contents, is_error ].hash
    end

    # Pretty print for better debugging
    def inspect
      "#<#{self.class.name} content: #{contents.inspect}, isError: #{is_error}>"
    end
  end
end
