# frozen_string_literal: true

class WeatherDashboardTemplate < ApplicationMCPResTemplate
  description "Interactive weather dashboard UI for the weather tool"
  uri_template "ui://weather/dashboard"
  mime_type :mcp_app

  ui csp: { connectDomains: %w[https://api.openweathermap.org] },
     prefersBorder: true

  def resolve
    render_ui(template: "mcp/ui/weather_dashboard")
  end
end
