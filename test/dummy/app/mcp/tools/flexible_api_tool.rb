# frozen_string_literal: true

class FlexibleApiTool < ApplicationMCPTool
  tool_name "flexible_api"
  title "Flexible API Caller"
  description "A demonstration tool that accepts additional properties beyond the defined ones"

  # Define core properties
  property :endpoint, type: "string", description: "API endpoint to call", required: true
  property :method, type: "string", description: "HTTP method", default: "GET"

  # Allow additional properties of any type
  additional_properties true

  def perform
    # Access defined properties normally
    api_endpoint = endpoint
    http_method = method

    # Access additional properties through the special accessor
    extra_params = additional_params

    # Demonstrate usage
    render text: "🌐 API Call Configuration:"
    render text: "📍 Endpoint: #{api_endpoint}"
    render text: "🔧 Method: #{http_method}"

    if extra_params.any?
      render text: "➕ Additional Parameters:"
      extra_params.each do |key, value|
        render text: "  #{key}: #{value.inspect}"
      end
    else
      render text: "➕ No additional parameters provided"
    end

    # Create structured output showing the separation
    render structured: {
      core_params: {
        endpoint: api_endpoint,
        method: http_method
      },
      additional_params: extra_params,
      total_params: attributes.merge(extra_params).size
    }
  end
end
