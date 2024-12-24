# frozen_string_literal: true

module ActionMCP
  module JsonRpc
    private

    def validate_id(id)
      raise Error, "ID must be a string or number" unless id.is_a?(String) || id.is_a?(Numeric)
      raise Error, "ID must not be null" if id.nil?
    end
  end
end
