# frozen_string_literal: true

module ActionMCP
  module Client
    # Factory for creating session stores
    class SessionStoreFactory
      def self.create(type = nil, **_options)
        type ||= default_type

        case type.to_sym
        when :volatile, :memory
          VolatileSessionStore.new
        when :active_record, :persistent
          ActiveRecordSessionStore.new
        when :test
          TestSessionStore.new
        else
          raise ArgumentError, "Unknown session store type: #{type}"
        end
      end

      def self.default_type
        ActionMCP.configuration.client_session_store_type
      end
    end
  end
end
