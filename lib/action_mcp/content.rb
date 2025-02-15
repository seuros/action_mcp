# frozen_string_literal: true

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

      def to_json(*)
        MultiJson.dump(to_h, *)
      end
    end

    autoload :Image
    autoload :Text
    autoload :Audio
    autoload :Resource
  end
end
