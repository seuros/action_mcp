# frozen_string_literal: true

module ActionMCP
  # Module for managing content within ActionMCP.
  module Content
    # Base class for MCP content items.
    class Base
      # @return [Symbol] The type of content.
      # @return [Hash, nil] Optional annotations for the content.
      attr_reader :type, :annotations

      # Initializes a new content item.
      #
      # @param type [Symbol] The type of content.
      # @param annotations [Hash, nil] Optional annotations for the content.
      def initialize(type, annotations: nil)
        @type = type
        @annotations = annotations
      end

      # Returns a hash representation of the content.
      #
      # @return [Hash] The hash representation.
      def to_h
        h = { type: @type }
        h[:annotations] = @annotations if @annotations
        h
      end

      # Returns a JSON representation of the content.
      #
      # @return [String] The JSON representation.
      def to_json(*)
        MultiJson.dump(to_h, *)
      end
    end
  end
end
