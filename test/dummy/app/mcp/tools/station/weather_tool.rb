# frozen_string_literal: true

module Station
  class WeatherTool < ApplicationMCPTool
    tool_name "station_weather"
    description "Get weather conditions for ground station operations"

    property :location, type: "string", description: "Station location"

    def perform
      render text: "Station weather at #{location}: Clear skies"
    end
  end
end
