# frozen_string_literal: true

module ActionMCP
  module Client
    class ResponsePromise
      def initialize
        @resolved = false
        @rejected = false
        @value = nil
        @error = nil
        @resolve_callbacks = []
        @reject_callbacks = []
      end

      def then(&block)
        @resolve_callbacks << block
        call_resolve_callbacks if @resolved
        self
      end

      def catch(&block)
        @reject_callbacks << block
        call_reject_callbacks if @rejected
        self
      end

      def resolve(value)
        return if @resolved || @rejected

        @resolved = true
        @value = value
        call_resolve_callbacks
      end

      def reject(error)
        return if @resolved || @rejected

        @rejected = true
        @error = error
        call_reject_callbacks
      end

      private

      def call_resolve_callbacks
        @resolve_callbacks.each { |callback| callback.call(@value) }
      end

      def call_reject_callbacks
        @reject_callbacks.each { |callback| callback.call(@error) }
      end
    end
  end
end
