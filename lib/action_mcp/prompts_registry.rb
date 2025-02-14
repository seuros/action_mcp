# frozen_string_literal: true

module ActionMCP
  class PromptsRegistry < RegistryBase
    class << self
      alias prompts items
      alias available_prompts enabled
    end
  end
end
