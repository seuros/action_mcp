module ActionMCP
  module Content
    extend ActiveSupport::Autoload
    # Base class for MCP content items.
    class Base
      attr_reader :type

      def initialize(type)
        @type = type
      end

      def to_h
        { type: @type }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end
    end
  end
end
