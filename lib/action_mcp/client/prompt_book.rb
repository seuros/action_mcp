# frozen_string_literal: true

module ActionMCP
  module Client
    # PromptBook
    #
    # A collection that manages and provides access to prompt templates form the MCP server.
    # The class stores prompt definitions along with their arguments and provides methods
    # for retrieving, filtering, and accessing prompts.
    #
    # Example usage:
    #   prompts_data = client.list_prompts # Returns array of prompt definitions
    #   book = PromptBook.new(prompts_data)
    #
    #   # Access a specific prompt by name
    #   summary_prompt = book.find("summarize_text")
    #
    #   # Get all prompts matching a criteria
    #   text_prompts = book.filter { |p| p.name.include?("text") }
    #
    class PromptBook
      # Initialize a new PromptBook with prompt definitions
      #
      # @param prompts [Array<Hash>] Array of prompt definition hashes, each containing
      #   name, description, and arguments keys
      def initialize(prompts = [])
        @prompts = prompts.map { |prompt_data| Prompt.new(prompt_data) }
      end

      # Return all prompts in the collection
      #
      # @return [Array<Prompt>] All prompt objects in the collection
      def all
        @prompts
      end

      # Find a prompt by name
      #
      # @param name [String] Name of the prompt to find
      # @return [Prompt, nil] The prompt with the given name, or nil if not found
      def find(name)
        @prompts.find { |prompt| prompt.name == name }
      end

      # Filter prompts based on a given block
      #
      # @yield [prompt] Block that determines whether to include a prompt
      # @yieldparam prompt [Prompt] A prompt from the collection
      # @yieldreturn [Boolean] true to include the prompt, false to exclude it
      # @return [Array<Prompt>] Prompts that match the filter criteria
      def filter(&block)
        @prompts.select(&block)
      end

      # Get a list of all prompt names
      #
      # @return [Array<String>] Names of all prompts in the collection
      def names
        @prompts.map(&:name)
      end

      # Number of prompts in the collection
      #
      # @return [Integer] The number of prompts
      def size
        @prompts.size
      end

      # Check if the collection contains a prompt with the given name
      #
      # @param name [String] The prompt name to check for
      # @return [Boolean] true if a prompt with the name exists
      def contains?(name)
        @prompts.any? { |prompt| prompt.name == name }
      end

      # Implements enumerable functionality for the collection
      include Enumerable

      # Yield each prompt in the collection to the given block
      #
      # @yield [prompt] Block to execute for each prompt
      # @yieldparam prompt [Prompt] A prompt from the collection
      # @return [Enumerator] If no block is given
      def each(&block)
        @prompts.each(&block)
      end

      # Internal Prompt class to represent individual prompts
      class Prompt
        attr_reader :name, :description, :arguments

        # Initialize a new Prompt instance
        #
        # @param data [Hash] Prompt definition hash containing name, description, and arguments
        def initialize(data)
          @name = data["name"]
          @description = data["description"]
          @arguments = data["arguments"] || []
        end

        # Get all required arguments for this prompt
        #
        # @return [Array<Hash>] Array of argument hashes that are required
        def required_arguments
          @arguments.select { |arg| arg["required"] }
        end

        # Get all optional arguments for this prompt
        #
        # @return [Array<Hash>] Array of argument hashes that are optional
        def optional_arguments
          @arguments.reject { |arg| arg["required"] }
        end

        # Check if the prompt has a specific argument
        #
        # @param name [String] Name of the argument to check for
        # @return [Boolean] true if the argument exists
        def has_argument?(name)
          @arguments.any? { |arg| arg["name"] == name }
        end

        # Generate a hash representation of the prompt
        #
        # @return [Hash] Hash containing prompt details
        def to_h
          {
            "name" => @name,
            "description" => @description,
            "arguments" => @arguments
          }
        end
      end
    end
  end
end
