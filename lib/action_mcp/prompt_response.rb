# frozen_string_literal: true

module ActionMCP
  class PromptResponse < BaseResponse
    ROLES = %w[user assistant].freeze

    attr_reader :messages

    # Delegate methods to the underlying messages array
    delegate :empty?, :size, :each, :find, :map, to: :messages

    def initialize
      super
      @messages = []
    end

    # Add a message to the response
    def add_message(role:, content:)
      normalized_role = role.to_s
      unless ROLES.include?(normalized_role)
        raise ArgumentError, "role must be one of: #{ROLES.join(', ')}"
      end
      raise ArgumentError, "content must be an MCP content object" unless content.is_a?(Hash)

      @messages << { role: normalized_role, content: Content::Validation.copy_content_block!(content) }
      self
    end

    # Add content directly (will be added as a user message)
    def add_content(content, role:)
      add_message(role: role, content: content.to_h)
      self
    end

    # Implementation of build_success_hash for PromptResponse
    def build_success_hash
      result = {
        messages: @messages
      }
      Content::Validation.validate_prompt_result!(result)
      result
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
