# frozen_string_literal: true

require "active_support/callbacks"

module ActionMCP
  # Builds a concern that defines one callback chain plus its
  # before_<event>, after_<event> and around_<event> class macros.
  module LifecycleCallbacks
    def self.for(event)
      Module.new do
        extend ActiveSupport::Concern
        include ActiveSupport::Callbacks

        included do
          define_callbacks event, skip_after_callbacks_if_terminated: true
        end

        class_methods do
          %i[before after around].each do |kind|
            define_method(:"#{kind}_#{event}") do |*filters, &blk|
              set_callback(event, kind, *filters, &blk)
            end
          end
        end
      end
    end
  end
end
