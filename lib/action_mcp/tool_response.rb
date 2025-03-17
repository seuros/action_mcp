# frozen_string_literal: true

module ActionMCP
  # Manages the collection of content objects for tool results
  class ToolResponse
    include Enumerable
    attr_reader :contents, :is_error

    delegate :empty?, :size, :each, :find, :map, to: :contents

    def initialize
      @contents = []
      @is_error = false
    end

    # Add content to the response
    def add(content)
      @contents << content
      content # Return the content for chaining
    end

    # Mark response as error
    def mark_as_error!(symbol = :invalid_request, message: nil, data: nil)
      @is_error = true
      @symbol = symbol
      @error_message = message
      @error_data = data
      self
    end

    # Convert to hash format expected by MCP protocol
    def to_h
      if @is_error
        JsonRpc::JsonRpcError.new(@symbol, message: @error_message, data: @error_data).to_h
      else
        {
          content: @contents.map(&:to_h)
        }
      end
    end

    # Alias as_json to to_h for consistency
    alias as_json to_h

    # Handle to_json directly
    def to_json(options = nil)
      to_h.to_json(options)
    end

    # Compare with hash for easier testing.
    def ==(other)
      case other
      when Hash
        # Convert both to normalized format for comparison
        hash_self = to_h.deep_transform_keys { |key| key.to_s.underscore }
        hash_other = other.deep_transform_keys { |key| key.to_s.underscore }
        hash_self == hash_other
      when ToolResponse
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
