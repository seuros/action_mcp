# frozen_string_literal: true

class ApiStatusTool < ApplicationMCPTool
  tool_name "api_status"
  description "Shows the status panel of the API service"

  renders_ui "ui://services/api"

  def perform
    render structured: { service: "api", status: "up" }
  end
end
