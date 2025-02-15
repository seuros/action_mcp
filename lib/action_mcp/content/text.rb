# frozen_string_literal: true

module ActionMCP
  module Content
    # Text content represents plain text messages.
    class Text < Base
      attr_reader :text

      def initialize(text)
        super("text")
        @text = text.to_s
      end

      def to_h
        super.merge(text: @text)
      end
    end
  end
end
