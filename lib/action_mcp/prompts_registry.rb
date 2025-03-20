# frozen_string_literal: true

module ActionMCP
  # Registry for managing prompts.
  class PromptsRegistry < RegistryBase
    class << self
      # @!method prompts
      #   Returns all registered prompts.
      #   @return [Hash] A hash of registered prompts.
      alias prompts items

      # Calls a prompt with the given name and arguments.
      #
      # @param prompt_name [String] The name of the prompt to call.
      # @param arguments [Hash] The arguments to pass to the prompt.
      # @return [Hash] A hash containing the prompt's response.
      def prompt_call(prompt_name, arguments)
        prompt = find(prompt_name)
        prompt = prompt.new(arguments)

        prompt.call
      end

      def item_klass
        Prompt
      end
    end
  end
end
