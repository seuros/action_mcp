# frozen_string_literal: true

module ActionMCP
  class PromptsRegistry < RegistryBase
    class << self
      alias prompts items
      alias available_prompts enabled

      def prompt_call(prompt_name, arguments)
        prompt = find(prompt_name)
        prompt = prompt.new(arguments)
        prompt.valid?
        if prompt.valid?
          {
            messages: [ {
              role: "user",
              content: prompt.call
            } ]
          }
        else
          {
            content: prompt.errors.full_messages.map { |msg| Content::Text.new(msg) },
            isError: true
          }
        end
      end
    end
  end
end
