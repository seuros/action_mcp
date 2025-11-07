# frozen_string_literal: true

module Spaceship
  class WeatherTool < ApplicationMCPTool
    # Explicitly set tool_name to match the default tool name pattern
    tool_name "spaceship_weather"
    description "Get weather conditions for spaceship operations"

    property :altitude, type: "number", description: "Altitude in meters"

    def perform
      render text: "Space weather at altitude #{altitude}m: Sunny vacuum conditions"
    end
  end
end
