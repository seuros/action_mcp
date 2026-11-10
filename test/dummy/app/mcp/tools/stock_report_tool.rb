# frozen_string_literal: true

# Reports stock levels. The partial and text details break the declared output
# schema on purpose, for the structured content validation tests.
class StockReportTool < ApplicationMCPTool
  tool_name "stock_report"
  description "Reports the stock level of an item"

  property :detail, type: "string", enum: %w[full partial text], default: "full"

  output_schema do
    string :name, required: true
    number :count, required: true
    object :metadata, additional_properties: true do
      string :source
    end
    additional_properties false
  end

  def perform
    case detail
    when "full" then render structured: { name: "widgets", count: 42 }
    when "partial" then render structured: { name: "widgets" }
    else render text: "widgets: 42"
    end
  end
end
