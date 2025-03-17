# frozen_string_literal: true

class WeatherForecastTool < ApplicationMCPTool
  description "Get detailed weather forecast for a location with progressive updates"

  property :location, type: "string", description: "City name or postal code", required: true
  property :days, type: "integer", description: "Number of forecast days (1-7)", required: false, default: 3

  validate :valid_location?
  def perform
    # Initial loading message
    render(text: "Fetching weather data for #{location}...")

    # Current conditions
    render(text: "Current conditions: #{current_conditions}")

    # Today's detailed forecast
    render(text: "Today's forecast: #{today_forecast}")

    # Weather alerts if any
    render(text: "⚠️ WEATHER ALERT: #{weather_alerts}") if has_alerts?

    # Extended forecast for requested days
    days_to_forecast = [ days.to_i, 7 ].min
    days_to_forecast = 3 if days_to_forecast < 1

    render(text: "Extended #{days_to_forecast}-day forecast:")

    (1..days_to_forecast).each do |day|
      render(text: extended_forecast(day))
      # Simulate delay for progressive updates
      sleep(0.3)
    end

    # Final summary
    render(text: "Weather data complete for #{location}. Forecast generated at #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
  rescue StandardError => e
    render(error: [ "Weather forecast failed: #{e.message}" ])
  end

  private

  def valid_location?
    # Mock validation - would check against a real database
    !location.nil? && location.strip.length.positive? && !location.match?(/^\d{1,2}$/)
  end

  def current_conditions
    # Generate random temperatures in Celsius
    temps = rand(18..29)
    conditions = [ "Sunny", "Partly Cloudy", "Cloudy", "Light Rain", "Thunderstorms" ].sample
    humidity = rand(30..90)
    wind = rand(0..24) # Changed to km/h for consistency with metric

    "#{temps}°C, #{conditions}, Humidity: #{humidity}%, Wind: #{wind} km/h"
  end

  def today_forecast
    high = rand(21..35)
    low = rand(13..24)
    precip = rand(0..100)

    "High #{high}°C, Low #{low}°C, #{precip}% chance of precipitation"
  end

  def has_alerts?
    # 20% chance of weather alert
    rand(1..5) == 1
  end

  def weather_alerts
    alerts = [
      "Flash Flood Warning until 8:00 PM",
      "Severe Thunderstorm Watch until 10:00 PM",
      "Heat Advisory in effect until tomorrow evening",
      "Wind Advisory in effect until 9:00 PM",
      "Air Quality Alert in effect for sensitive groups"
    ]

    alerts.sample
  end

  def extended_forecast(day_offset)
    day_names = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
    today = Time.now.wday
    future_day = (today + day_offset) % 7

    high = rand(18..35)
    low = rand(10..24)
    conditions = [ "Sunny", "Partly Cloudy", "Cloudy", "Light Rain", "Scattered Showers", "Thunderstorms",
                  "Clear" ].sample
    precipitation = rand(0..100)

    "#{day_names[future_day]}: #{conditions}, High #{high}°C, Low #{low}°C, #{precipitation}% chance of precipitation"
  end
end
