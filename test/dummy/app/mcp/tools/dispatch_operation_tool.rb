# frozen_string_literal: true

class DispatchOperationTool < ApplicationMCPTool
  DEFAULT_LABELS = %w[bug feature].freeze

  tool_name "dispatch_operation"
  description "Runs one of the operations the current user is allowed to use"

  property :operation, type: "string", required: true,
                       enum: -> { current_user&.allowed_operations || %w[status] }
  collection :labels, type: "string",
                      enum: -> { session_data&.dig("labels") || DEFAULT_LABELS },
                      max_items: -> { (session_data&.dig("labels") || DEFAULT_LABELS).size }

  def perform
    render text: "Dispatched #{operation}"
  end
end
