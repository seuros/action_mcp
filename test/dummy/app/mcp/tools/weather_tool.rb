# frozen_string_literal: true

class WeatherTool < ApplicationMCPTool
  tool_name "weather"
  description "Get weather information for a location with structured output"

  # Input properties (existing pattern)
  property :location, type: "string", required: true, description: "City name or coordinates"
  property :units, type: "string", default: "celsius", enum: [ "celsius", "fahrenheit" ], description: "Temperature units"
  property :include_forecast, type: "boolean", default: false, description: "Include 5-day forecast"

  # Output schema (new feature!)
  output_schema do
    property :success, type: "boolean", required: true, description: "Whether request was successful"
    property :message, type: "string", description: "Human readable message"

    # Nested current weather object
    object :current do
      property :temperature, type: "number", required: true, description: "Current temperature"
      property :condition, type: "string", required: true, description: "Weather condition"
      property :humidity, type: "number", minimum: 0, maximum: 100, description: "Humidity percentage"
      property :wind_speed, type: "number", minimum: 0, description: "Wind speed"
      property :timestamp, type: "string", format: "date-time", description: "Observation time"
    end

    # Optional forecast array
    array :forecast, description: "5-day weather forecast" do
      object :day do
        property :date, type: "string", format: "date", required: true
        property :high, type: "number", required: true
        property :low, type: "number", required: true
        property :condition, type: "string", required: true
        property :precipitation, type: "number", minimum: 0, default: 0
      end
    end

    # Metadata object
    object :metadata do
      property :location_found, type: "string", description: "Resolved location name"
      property :data_source, type: "string", default: "mock", description: "Weather data provider"
      property :response_time_ms, type: "number", minimum: 0, description: "API response time"
    end
  end

  def perform
    start_time = Time.current

    # Simulate weather API call
    render text: "Fetching weather for #{location}..."

    # Simulate some processing time
    sleep(0.1) if Rails.env.development?

    # Build the structured response
    weather_data = {
      success: true,
      message: "Weather data retrieved successfully for #{location}",
      current: {
        temperature: units == "fahrenheit" ? 72.5 : 22.5,
        condition: "Partly cloudy",
        humidity: 65,
        wind_speed: 8.3,
        timestamp: Time.current.iso8601
      },
      metadata: {
        location_found: location,
        data_source: "OpenWeatherMap Mock",
        response_time_ms: ((Time.current - start_time) * 1000).round(1)
      }
    }

    # Add forecast if requested
    if include_forecast
      weather_data[:forecast] = [
        {
          date: Date.current.to_s,
          high: units == "fahrenheit" ? 75 : 24,
          low: units == "fahrenheit" ? 68 : 20,
          condition: "Sunny",
          precipitation: 0
        },
        {
          date: (Date.current + 1).to_s,
          high: units == "fahrenheit" ? 73 : 23,
          low: units == "fahrenheit" ? 66 : 19,
          condition: "Light rain",
          precipitation: 2.5
        }
        # ... more forecast days
      ]

      render text: "Including 5-day forecast"
    end

    # Some additional text output
    render text: "Temperature: #{weather_data[:current][:temperature]}°#{units == 'fahrenheit' ? 'F' : 'C'}"
    render text: "Conditions: #{weather_data[:current][:condition]}"

    # Return structured data
    render structured: weather_data
  end
end
