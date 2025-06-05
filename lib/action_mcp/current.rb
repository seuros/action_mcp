# frozen_string_literal: true

module ActionMCP
  class Current < ActiveSupport::CurrentAttributes
    attribute :user
    attribute :gateway

    def user=(user)
      super
      set_user_time_zone if user.respond_to?(:time_zone)
    end

    private

    def set_user_time_zone
      Time.zone = user.time_zone
    end
  end
end
