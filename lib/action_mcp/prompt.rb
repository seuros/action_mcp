# frozen_string_literal: true

module ActionMCP
  # Abstract base class for Prompts
  class Prompt < Capability
    class_attribute :_prompt_name, instance_accessor: false
    class_attribute :_argument_definitions, instance_accessor: false, default: []
    class_attribute :abstract_prompt, instance_accessor: false, default: false

    def self.inherited(subclass)
      super
      return if subclass == Prompt
      return if subclass.name == "ApplicationPrompt"

      subclass.abstract_prompt = false

      # Automatically register the subclass with the PromptsRegistry
      PromptsRegistry.register(subclass.prompt_name, subclass)
    end

    # Marks the prompt as abstract.
    #
    # @return [void]
    def self.abstract!
      self.abstract_prompt = true
      # If already registered, you might want to unregister it here.
    end

    # Checks if the prompt is abstract.
    #
    # @return [Boolean] True if the prompt is abstract, false otherwise.
    def self.abstract?
      abstract_prompt
    end

    # ---------------------------------------------------
    # Prompt Name
    # ---------------------------------------------------
    # Gets or sets the prompt name.
    #
    # @param name [String, nil] The prompt name to set.
    # @return [String] The prompt name.
    def self.prompt_name(name = nil)
      if name
        self._prompt_name = name
      else
        _prompt_name || default_prompt_name
      end
    end

    # Returns the default prompt name based on the class name.
    #
    # @return [String] The default prompt name.
    def self.default_prompt_name
      name.demodulize.underscore.sub(/_prompt$/, "")
    end

    # ---------------------------------------------------
    # Description
    # ---------------------------------------------------
    # @param text [String, nil] The description to set.
    # @return [String] The prompt description.
    def self.description(text = nil)
      if text
        self._description = text
      else
        _description
      end
    end

    # ---------------------------------------------------
    # Argument DSL
    # ---------------------------------------------------
    # Defines an argument for the prompt.
    #
    # @param arg_name [Symbol] The name of the argument.
    # @param description [String] The description of the argument.
    # @param required [Boolean] Whether the argument is required.
    # @param default [Object] The default value of the argument.
    # @return [void]
    def self.argument(arg_name, description: "", required: false, default: nil)
      arg_def = {
        name: arg_name.to_s,
        description: description,
        required: required,
        default: default
      }
      self._argument_definitions += [ arg_def ]

      # Register the attribute so it's recognized by ActiveModel
      attribute arg_name, :string, default: default
      return unless required

      validates arg_name, presence: true
    end

    # Returns the list of argument definitions.
    #
    # @return [Array<Hash>] The list of argument definitions.
    def self.arguments
      _argument_definitions
    end

    # ---------------------------------------------------
    # Convert prompt definition to Hash
    # ---------------------------------------------------
    # @return [Hash] The prompt definition as a Hash.
    def self.to_h
      {
        name: prompt_name,
        description: description.presence,
        arguments: arguments.map { |arg| arg.slice(:name, :description, :required) }
      }.compact
    end

    # ---------------------------------------------------
    # Class-level call method
    # ---------------------------------------------------
    # Receives a Hash of params, initializes a prompt instance,
    # validates it, and if valid, calls the instance call method.
    # If invalid, raises a JsonRpcError with code :invalid_params.
    #
    # Usage:
    #   result = MyPromptClass.call(params)
    #
    # Raises:
    #   ActionMCP::JsonRpc::JsonRpcError(:invalid_params) if validation fails.
    #
    # @param params [Hash] The parameters for the prompt.
    # @return [Object] The result of the prompt's call method.
    def self.call(params)
      prompt = new(params) # Initialize an instance with provided params
      unless prompt.valid?
        # Collect all validation errors into a single string or array
        errors_str = prompt.errors.full_messages.join(", ")

        raise ActionMCP::JsonRpc::JsonRpcError.new(
          :invalid_params,
          message: "Prompt validation failed: #{errors_str}",
          data: { errors: prompt.errors }
        )
      end

      # If we reach here, the prompt is valid
      prompt.call
    end

    # ---------------------------------------------------
    # Instance call method
    # ---------------------------------------------------
    # By default, does nothing. Override in your subclasses to
    # perform custom prompt processing. (Return a payload if needed)
    #
    # Usage: Called internally after validation in self.call
    #
    # @raise [NotImplementedError] Subclasses must implement the call method.
    # @return [Array<Content>] Array of Content objects is expected as return value
    def call
      raise NotImplementedError, "Subclasses must implement the call method"
      # Default implementation (no-op)
      # In a real subclass, you might do:
      #  # Perform logic, e.g. analyze code, etc.
      #  # Return something meaningful.
    end
  end
end
