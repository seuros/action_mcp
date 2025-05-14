# frozen_string_literal: true

module ActionMCP
  module Content
    # Base class for all content types, supporting annotations.
    class Base
      attr_reader :type, :annotations

      # Initializes a new content base.
      #
      # @param type [String] The type of the content (e.g., "text", "image", etc.)
      # @param annotations [Hash, nil] Optional annotations for the content.
      def initialize(type, annotations: nil)
        @type = type
        @annotations = annotations
      end

      # Returns a hash representation of the base content.
      #
      # @return [Hash] The hash representation of the base content.
      def to_h
        h = { type: @type }
        h[:annotations] = @annotations if @annotations
        h
      end
    end
  end
end
