# frozen_string_literal: true

module ActionMCP
  class PromptsRegistry < RegistryBase
    class << self
      alias_method :prompts, :items
      alias_method :available_prompts, :enabled
    end
  end
end
