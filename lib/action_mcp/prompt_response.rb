# frozen_string_literal: true

module ActionMCP
  class PromptResponse
    attr_reader :messages, :description

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

    # Alias to_h to as_json for consistency
    alias_method :to_h, :as_json

    # Handle to_json directly
    def to_json(options = nil)
      to_h.to_json(options)
    end

    # Pretty print for better debugging
    def inspect
      "#<#{self.class.name} messages: #{messages.size}"
    end
  end
end
