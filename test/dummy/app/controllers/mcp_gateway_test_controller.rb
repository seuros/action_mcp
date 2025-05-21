# frozen_string_literal: true

class MCPGatewayTestController < ApplicationController
  def up
    gateway_class = ActionMCP.configuration.gateway_class
    gateway = gateway_class.new
    gateway.call(request)

    render json: {
      user_id: ActionMCP.configuration.current_class.user&.id
    }
  end
end
