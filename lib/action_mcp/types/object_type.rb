# frozen_string_literal: true

module ActionMCP
  module Types
    class ObjectType < ActiveModel::Type::Value
      def type
        :object
      end
    end
  end
end
