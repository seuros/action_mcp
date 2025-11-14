# frozen_string_literal: true

module Mars
  class WeatherTool < ApplicationMCPTool
    description "Get weather conditions for Mars"

    def perform
      render text: "Mars weather is pretty cold!"
    end
  end
end
