# frozen_string_literal: true

class MCPGatewayTestController < ApplicationController
  def up
    gateway_class = ActionMCP.configuration.gateway_class
    gateway = gateway_class.new(request)
    gateway.call

    render json: {
      user_id: ActionMCP::Current.user&.id,
      user_email: ActionMCP::Current.user&.email
    }
  rescue ActionMCP::UnauthorizedError => e
    render json: { error: e.message }, status: :unauthorized
  end
end
