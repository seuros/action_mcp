# frozen_string_literal: true

module ActionMCP
  module Content
    # Text content represents plain text messages.
    class Text < Base
      # @return [String] The text content.
      attr_reader :text

      # Initializes a new Text content.
      #
      # @param text [String] The text content.
      def initialize(text)
        super("text")
        @text = text.to_s
      end

      # Returns a hash representation of the text content.
      #
      # @return [Hash] The hash representation of the text content.
      def to_h
        super.merge(text: @text)
      end
    end
  end
end
