# frozen_string_literal: true

module ActionMCP
  class PromptResponse
    include Enumerable
    attr_reader :messages, :is_error

    # Delegate methods to the underlying messages array
    delegate :empty?, :size, :each, :find, :map, to: :messages

    def initialize
      @messages = []
      @is_error = false
    end

    # Add a message to the response
    def add_message(role:, content:)
      @messages << { role: role, content: content }
      self
    end

    # Add content directly (will be added as a user message)
    def add_content(content, role:)
      add_message(role: role, content: content.to_h)
      self
    end

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
          messages: @messages
        }
      end
    end

    # Alias as_json to to_h for consistency
    alias as_json to_h

    # Handle to_json directly
    def to_json(options = nil)
      to_h.to_json(options)
    end

    # Compare with hash for easier testing
    def ==(other)
      case other
      when Hash
        # Convert both to normalized format for comparison
        hash_self = to_h.deep_transform_keys { |key| key.to_s.underscore }
        hash_other = other.deep_transform_keys { |key| key.to_s.underscore }
        hash_self == hash_other
      when PromptResponse
        messages == other.messages
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
      [ messages ].hash
    end

    # Pretty print for better debugging
    def inspect
      "#<#{self.class.name} messages: #{messages.inspect}>"
    end
  end
end
