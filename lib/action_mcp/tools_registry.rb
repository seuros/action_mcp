# frozen_string_literal: true

# frozen_string_literal: true

module ActionMCP
  class ToolsRegistry < RegistryBase
    class << self
      alias tools items
      alias available_tools enabled
    end
  end
end
