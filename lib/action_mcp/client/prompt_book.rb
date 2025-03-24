# frozen_string_literal: true

module ActionMCP
  module Client
    # PromptBook
    #
    # A collection that manages and provides access to prompt templates from the MCP server.
    # The class stores prompt definitions along with their arguments and provides methods
    # for retrieving, filtering, and accessing prompts. It supports lazy loading of prompts
    # when initialized with a client.
    #
    # Example usage:
    #   # Eager loading
    #   prompts_data = client.list_prompts # Returns array of prompt definitions
    #   book = PromptBook.new(prompts_data)
    #
    #   # Lazy loading
    #   book = PromptBook.new([], client)
    #   prompts = book.all # Prompts are loaded here
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
      # @param client [Object, nil] Optional client for lazy loading of prompts
      attr_reader :client

      def initialize(prompts, client)
        self.prompts = prompts
        @client = client
        @loaded = !prompts.empty?
      end

      # Return all prompts in the collection. If initialized with a client and prompts
      # haven't been loaded yet, this will trigger lazy loading from the client.
      #
      # @return [Array<Prompt>] All prompt objects in the collection
      def all
        load_prompts unless @loaded
        @prompts
      end

      # Find a prompt by name
      #
      # @param name [String] Name of the prompt to find
      # @return [Prompt, nil] The prompt with the given name, or nil if not found
      def find(name)
        all.find { |prompt| prompt.name == name }
      end

      # Filter prompts based on a given block
      #
      # @yield [prompt] Block that determines whether to include a prompt
      # @yieldparam prompt [Prompt] A prompt from the collection
      # @yieldreturn [Boolean] true to include the prompt, false to exclude it
      # @return [Array<Prompt>] Prompts that match the filter criteria
      def filter(&block)
        all.select(&block)
      end

      # Get a list of all prompt names
      #
      # @return [Array<String>] Names of all prompts in the collection
      def names
        all.map(&:name)
      end

      # Number of prompts in the collection
      #
      # @return [Integer] The number of prompts
      def size
        all.size
      end

      # Check if the collection contains a prompt with the given name
      #
      # @param name [String] The prompt name to check for
      # @return [Boolean] true if a prompt with the name exists
      def contains?(name)
        all.any? { |prompt| prompt.name == name }
      end

      # Implements enumerable functionality for the collection
      include Enumerable

      # Yield each prompt in the collection to the given block
      #
      # @yield [prompt] Block to execute for each prompt
      # @yieldparam prompt [Prompt] A prompt from the collection
      # @return [Enumerator] If no block is given
      def each(&block)
        all.each(&block)
      end

      # Force reload all prompts from the client and return them
      #
      # @return [Array<Prompt>] All prompt objects in the collection
      def all!
        load_prompts(force: true)
        all
      end

      # Convert raw prompt data into Prompt objects
      #
      # @param prompts [Array<Hash>] Array of prompt definition hashes
      def prompts=(prompts)
        @prompts = prompts.map { |data| Prompt.new(data) }
      end

      private

      # Load or reload prompts using the client
      #
      # @param force [Boolean] Whether to force reload even if prompts are already loaded
      # @return [void]
      def load_prompts(force: false)
        return if @loaded && !force

        begin
          @client.list_prompts
          @loaded = true
        rescue StandardError => e
          Rails.logger.error("Failed to load prompts: #{e.message}")
          @loaded = true unless @prompts.empty?
        end
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
