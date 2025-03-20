module ActionMCP
  module Instrumentation
    module Instrumentation # :nodoc:
      extend ActiveSupport::Concern

      included do
        around_perform do |_, block|
          instrument(:perform, &block)
        end
      end

      private

      def instrument(operation, payload = {}, &block)
        payload[:mcp] = self

        # Include type information (tool/prompt)
        payload[:type] = self.class.type

        ActiveSupport::Notifications.instrument("#{operation}.action_mcp", payload) do
          block.call
        end
      end
    end
  end
end
