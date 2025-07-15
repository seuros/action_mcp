# frozen_string_literal: true

class ErrorRaisingTool < ApplicationMCPTool
  tool_name "error_raising"
  description "A tool that always raises an error"

  property :input, type: "string", description: "Input that will be ignored", required: false

  def perform
    raise StandardError, "Test error occurred"
  end
end
