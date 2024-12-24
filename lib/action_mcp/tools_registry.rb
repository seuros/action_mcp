# frozen_string_literal: true

# frozen_string_literal: true

module ActionMCP
  class ToolsRegistry < RegistryBase
    class << self
      alias_method :tools, :items
      alias_method :available_tools, :enabled
    end
  end
end
