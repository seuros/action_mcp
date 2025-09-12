# frozen_string_literal: true

class EnvironmentTool < ApplicationMCPTool
  tool_name "environment"
  description "Test tool for environment validation"

  # Property without enum constraint - validation will happen in perform
  property :env,
           type: "string",
           description: "Environment to use",
           required: true

  def perform
    valid_environments = %w[development test production]
    unless valid_environments.include?(env)
      report_error("Validation failed: '#{env}' is not supported")
      return
    end

    render text: "Successfully set environment to: #{env}"
  end
end
