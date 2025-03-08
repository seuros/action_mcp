# frozen_string_literal: true

module ActionMCP
  # Module for managing content within ActionMCP.
  module Content
    # Base class for MCP content items.
    class Base
      # @return [Symbol] The type of content.
      attr_reader :type

      # Initializes a new content item.
      #
      # @param type [Symbol] The type of content.
      def initialize(type)
        @type = type
      end

      # Returns a hash representation of the content.
      #
      # @return [Hash] The hash representation.
      def to_h
        { type: @type }
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
