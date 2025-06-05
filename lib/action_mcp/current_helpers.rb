# frozen_string_literal: true

module ActionMCP
  module CurrentHelpers
    extend ActiveSupport::Concern

    protected

    # Access the current user from ActionMCP::Current
    def current_user
      ActionMCP::Current.user
    end

    # Access the current gateway from ActionMCP::Current
    def current_gateway
      ActionMCP::Current.gateway
    end
  end
end
