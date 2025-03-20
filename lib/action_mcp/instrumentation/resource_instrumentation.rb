# frozen_string_literal: true

module ActionMCP
  module Instrumentation
    module ResourceInstrumentation # :nodoc:
      extend ActiveSupport::Concern

      included do
        around_resolve do |_, block|
          instrument(:resolve, &block)
        end
      end

      private
      def instrument(operation, payload = {}, &block)
        payload[:resource_template] = self
        payload[:uri_template] = uri_template if respond_to?(:uri_template)
        payload[:mime_type] = mime_type if respond_to?(:mime_type)

        ActiveSupport::Notifications.instrument("#{operation}.action_mcp_resource", payload) do
          value = block.call if block
          if value
            payload[:success] = true
            payload[:resource] = value
          else
            payload[:success] = false
          end
          payload[:aborted] = @_halted_callback_hook_called if defined?(@_halted_callback_hook_called)
          @_halted_callback_hook_called = nil
          value
        end
      end

      def halted_callback_hook(*)
        super
        @_halted_callback_hook_called = true
      end
    end
  end
end
