# frozen_string_literal: true

class AnalyzeCsvTool < ApplicationTool
  description "Analyze a CSV file"

  property :filepath, type: "string", description: "Path to CSV file"
  collection :operations, type: "string", description: "Operations to perform"

  validates :operations, inclusion: { in: %w[sum average count] }

  def call
    result = operations.to_h { |op| [ op, rand(1..100) ] }
    render_text(result.to_json)
  end
end
