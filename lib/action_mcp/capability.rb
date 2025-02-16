# frozen_string_literal: true

require_relative "renderable"

module ActionMCP
  class Capability
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Renderable

    class_attribute :_description, instance_accessor: false, default: ""

    def self.description(text = nil)
      if text
        self._description = text
      else
        _description
      end
    end
  end
end
