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
    if has_alerts?
      render(text: "⚠️ WEATHER ALERT: #{weather_alerts}")
    end

    # Extended forecast for requested days
    days_to_forecast = [ days.to_i, 7 ].min
    days_to_forecast = 3 if days_to_forecast < 1

    render(text: "Extended #{days_to_forecast}-day forecast:")

    (1..days_to_forecast).each do |day|
      render(text: extended_forecast(day))
      sleep(0.3)
    end

    # Final summary
    render(text: "Weather data complete for #{location}. Forecast generated at #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
  rescue => e
    render(error: [ "Weather forecast failed: #{e.message}" ])
  end

  private

  def valid_location?
    # Mock validation - would check against a real database
    !location.nil? && location.strip.length > 0 && !location.match?(/^\d{1,2}$/)
  end

  def current_conditions
    temps = rand(65..85)
    conditions = [ "Sunny", "Partly Cloudy", "Cloudy", "Light Rain", "Thunderstorms" ].sample
    humidity = rand(30..90)
    wind = rand(0..15)

    "#{temps}°F, #{conditions}, Humidity: #{humidity}%, Wind: #{wind} mph"
  end

  def today_forecast
    high = rand(70..95)
    low = rand(55..75)
    precip = rand(0..100)

    "High #{high}°F, Low #{low}°F, #{precip}% chance of precipitation"
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
    day_names = [ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" ]
    today = Time.now.wday
    future_day = (today + day_offset) % 7

    high = rand(65..95)
    low = rand(50..75)
    conditions = [ "Sunny", "Partly Cloudy", "Cloudy", "Light Rain", "Scattered Showers", "Thunderstorms", "Clear" ].sample
    precip = rand(0..100)

    "#{day_names[future_day]}: #{conditions}, High #{high}°F, Low #{low}°F, #{precip}% chance of precipitation"
  end
end
