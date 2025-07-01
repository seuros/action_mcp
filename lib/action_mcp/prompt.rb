# frozen_string_literal: true

module ActionMCP
  # Abstract base class for Prompts
  class Prompt < Capability
    include ActionMCP::Callbacks
    include ActionMCP::CurrentHelpers
    class_attribute :_argument_definitions, instance_accessor: false, default: []
    class_attribute :_meta, instance_accessor: false, default: {}

    # ---------------------------------------------------
    # Prompt Name
    # ---------------------------------------------------
    # Gets or sets the prompt name.
    #
    # @param name [String, nil] The prompt name to set.
    # @return [String] The prompt name.
    def self.prompt_name(name = nil)
      if name
        self._capability_name = name
      else
        _capability_name || default_prompt_name
      end
    end

    # Returns the default prompt name based on the class name.
    #
    # @return [String] The default prompt name.
    def self.default_prompt_name
      name.demodulize.underscore.sub(/_prompt$/, "")
    end

    class << self
      alias default_capability_name default_prompt_name

      def type
        :prompt
      end

      # Sets or retrieves the _meta field
      def meta(data = nil)
        if data
          raise ArgumentError, "_meta must be a hash" unless data.is_a?(Hash)
          self._meta = _meta.merge(data)
        else
          _meta
        end
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
    # @param enum [Array<String>] The list of allowed values for the argument.
    # @param type [Symbol] The type of the argument (e.g., :string, :integer, :boolean). Defaults to :string.
    # @return [void]
    def self.argument(arg_name, description: "", required: false, default: nil, enum: nil, type: :string)
      arg_def = {
        name: arg_name.to_s,
        description: description,
        required: required,
        default: default,
        enum: enum
      }
      self._argument_definitions += [ arg_def ]

      # Register the attribute so it's recognized by ActiveModel
      attribute arg_name, type, default: default
      validates arg_name, presence: true if required

      return unless enum.present?

      validates arg_name, inclusion: { in: enum }, allow_blank: !required
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
      result = {
        name: prompt_name,
        description: description.presence,
        arguments: arguments.map { |arg| arg.slice(:name, :description, :required, :type) }
      }.compact

      # Add _meta if present
      result[:_meta] = _meta if _meta.any?

      result
    end

    # ---------------------------------------------------
    # Class-level call method
    # ---------------------------------------------------
    # Receives a Hash of params, initializes a prompt instance,
    # validates it, and if valid, calls the instance call method.
    # If invalid, raises a JsonRpcError with code :invalid_params.
    #
    # @param params [Hash] The parameters for the prompt.
    # @return [PromptResponse] The result of the prompt's call method.
    def self.call(params)
      prompt = new(params) # Initialize an instance with provided params

      # If we reach here, the prompt is valid
      prompt.call
    end

    # ---------------------------------------------------
    # Instance Methods
    # ---------------------------------------------------

    # Public entry point for executing the prompt
    # Returns a PromptResponse object containing messages
    def call
      @response = PromptResponse.new

      # Check validations before proceeding
      if valid?
        begin
          run_callbacks :perform do
            perform # Invoke the subclass-specific logic if valid
          end
        rescue StandardError
          # Handle exceptions during execution
          @response.mark_as_error!(:internal_error, message: "Unhandled Error executing prompt")
        end
      else
        # Handle validation failure
        @response.mark_as_error!(:invalid_params, message: "Invalid input", data: errors.full_messages)
      end

      @response # Return the response with collected messages
    end

    def inspect
      attributes_hash = attributes.transform_values(&:inspect)

      response_info = if defined?(@response) && @response
                        "response: #{@response.messages.size} message(s)"
      else
                        "response: nil"
      end

      errors_info = errors.any? ? ", errors: #{errors.full_messages}" : ""

      "#<#{self.class.name} #{attributes_hash.map do |k, v|
        "#{k}: #{v.inspect}"
      end.join(', ')}, #{response_info}#{errors_info}>"
    end

    # Override render to collect messages
    def render(**args)
      content = super(**args.slice(:text, :audio, :image, :resource, :mime_type, :blob))
      @response.add_content(content, role: args.fetch(:role, "user")) # Add to the response
      content # Return the content for potential use in perform
    end

    protected

    # Abstract method for subclasses to implement their logic
    # Expected to use render to produce Content objects or add_message for messages
    def perform
      raise NotImplementedError, "Subclasses must implement the perform method"
    end
  end
end
