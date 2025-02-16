# frozen_string_literal: true

module ActionMCP
  # Registry for managing prompts.
  class PromptsRegistry < RegistryBase
    class << self
      # @!method prompts
      #   Returns all registered prompts.
      #   @return [Hash] A hash of registered prompts.
      alias prompts items
      # @!method available_prompts
      #   Returns all enabled prompts.
      #   @return [Hash] A hash of enabled prompts.
      alias available_prompts enabled

      # Calls a prompt with the given name and arguments.
      #
      # @param prompt_name [String] The name of the prompt to call.
      # @param arguments [Hash] The arguments to pass to the prompt.
      # @return [Hash] A hash containing the prompt's response.
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
