# frozen_string_literal: true

module ActionMCP
  class SamplingRequest
    class << self
      attr_reader :default_messages, :default_system_prompt, :default_context,
                  :default_model_hints, :default_intelligence_priority,
                  :default_max_tokens, :default_temperature

      def configure
        yield self
      end

      def messages(messages = nil)
        if messages
          @default_messages = messages.map do |msg|
            mutate_content(msg)
          end
        end
        @default_messages ||= []
      end

      def system_prompt(prompt = nil)
        @default_system_prompt = prompt if prompt
        @default_system_prompt
      end

      def include_context(context = nil)
        @default_context = context if context
        @default_context
      end

      def model_hints(hints = nil)
        @default_model_hints = hints if hints
        @model_hints ||= []
      end

      def intelligence_priority(priority = nil)
        @default_intelligence_priority = priority if priority
        @intelligence_priority ||= 0.9
      end

      def max_tokens(tokens = nil)
        @default_max_tokens = tokens if tokens
        @max_tokens ||= 500
      end

      def temperature(temp = nil)
        @default_temperature = temp if temp
        @temperature ||= 0.7
      end

      private

      def mutate_content(msg)
        content = msg[:content]
        if content.is_a?(ActionMCP::Content) || (content.respond_to?(:to_h) && !content.is_a?(Hash))
          { role: msg[:role], content: content.to_h }
        else
          msg
        end
      end
    end

    attr_accessor :system_prompt, :model_hints, :intelligence_priority, :max_tokens, :temperature
    attr_reader :messages, :context

    def initialize
      @messages = self.class.default_messages.dup
      @system_prompt = self.class.default_system_prompt
      @context = self.class.default_context
      @model_hints = self.class.default_model_hints.dup
      @intelligence_priority = self.class.default_intelligence_priority
      @max_tokens = self.class.default_max_tokens
      @temperature = self.class.default_temperature

      yield self if block_given?
    end

    def messages=(value)
      @messages = value.map do |msg|
        self.class.send(:mutate_content, msg)
      end
    end

    def include_context=(value)
      @context = value
    end

    def add_message(content, role: "user")
      if content.is_a?(Content::Base) || (content.respond_to?(:to_h) && !content.is_a?(Hash))
        @messages << { role: role, content: content.to_h }
      else
        content = Content::Text.new(content).to_h if content.is_a?(String)
        @messages << { role: role, content: content }
      end
    end

    def to_h
      {
        messages: messages.map { |msg| { role: msg[:role], content: msg[:content] } },
        systemPrompt: system_prompt,
        includeContext: context,
        modelPreferences: {
          hints: model_hints.map { |name| { name: name } },
          intelligencePriority: intelligence_priority
        },
        maxTokens: max_tokens,
        temperature: temperature
      }.compact
    end
  end
end
