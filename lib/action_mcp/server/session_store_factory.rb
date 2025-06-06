# frozen_string_literal: true

module ActionMCP
  module Server
    class SessionStoreFactory
      def self.create(type = nil, **options)
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
        if Rails.env.test?
          :volatile # Use volatile for tests unless explicitly using :test
        elsif Rails.env.production?
          :active_record
        else
          :volatile
        end
      end
    end
  end
end
