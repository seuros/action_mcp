# frozen_string_literal: true

class ConfigureServiceTool < ApplicationMCPTool
  tool_name "configure_service"
  description "Points a service at an endpoint"

  property :mode, type: "string", enum: %w[fast safe], required: true
  property :port, type: "integer", minimum: 1, maximum: 65_535, required: true
  property :endpoint, type: "string", format: "uri", required: true
  property :settings,
           type: "object",
           properties: { enabled: { type: "boolean" } },
           all_of: [ { required: [ "enabled" ] } ],
           additional_properties: false,
           required: true
  additional_properties false

  def perform
    render text: "#{mode} service on #{endpoint}:#{port}"
  end
end
