# frozen_string_literal: true

class TriageTicketTool < ApplicationMCPTool
  tool_name "triage_ticket"
  description "Files a ticket with labels, priority and an estimate"

  collection :labels, type: "string", enum: %w[bug feature docs], min_items: 1, max_items: 3, unique_items: true
  collection :watchers, type: "string", maxItems: 2
  property :priority, type: "string", enum: %w[low normal high]
  property :code, type: "string", min_length: 2, max_length: 4
  property :estimate, type: "number", multiple_of: 5, exclusive_minimum: 0

  def perform
    render text: "Filed #{labels.join(', ')} ticket"
  end
end
