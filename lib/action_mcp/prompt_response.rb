# frozen_string_literal: true

module ActionMCP
  class PromptResponse < BaseResponse
    attr_reader :messages

    # Delegate methods to the underlying messages array
    delegate :empty?, :size, :each, :find, :map, to: :messages

    def initialize
      super
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

    # Implementation of build_success_hash for PromptResponse
    def build_success_hash
      {
        messages: @messages
      }
    end

    # Implementation of compare_with_same_class for PromptResponse
    def compare_with_same_class(other)
      messages == other.messages
    end

    # Implementation of hash_components for PromptResponse
    def hash_components
      [ messages ]
    end

    # Pretty print for better debugging
    def inspect
      "#<#{self.class.name} messages: #{messages.inspect}>"
    end
  end
end
