# frozen_string_literal: true

class AnalyzeCsvTool < ApplicationTool
  tool_name "analyze_csv"
  description "Analyze a CSV file"

  property :filepath, type: "string", description: "Path to CSV file"
  property :operations, type: "array", description: "Operations to perform",
                        items: { enum: %w[sum average count] }
end
