# frozen_string_literal: true

module ActionMCP
  class PromptResponse
    include Enumerable

    attr_reader :messages

    # Delegate methods to the underlying messages array
    delegate :empty?, :size, :each, :find, :map, to: :messages

    def initialize
      @messages = []
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

    # Convert to hash format expected by MCP protocol
    def to_h
      {
        messages: @messages
      }
    end

    # Alias as_json to to_h for consistency
    alias_method :as_json, :to_h

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
