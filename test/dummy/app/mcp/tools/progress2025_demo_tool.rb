# frozen_string_literal: true

# test/dummy/app/mcp/tools/progress_2025_demo_tool.rb
class Progress2025DemoTool < ApplicationMCPTool
  tool_name "progress_2025_demo"
  description "Demo tool showing 2025-03-26 progress notifications"

  property :total_items, type: "integer", description: "Total items to process", default: 5
  property :delay_ms, type: "integer", description: "Delay between items in milliseconds", default: 10

  def perform
    # Extract progressToken from request metadata if available
    progress_token = extract_progress_token

    # Log that we're starting the tool with this progress token
    Rails.logger.info "Starting Progress2025DemoTool with token: #{progress_token}"

    # Create an array to hold our output content
    output_content = []

    # Make sure we process at least one item for testing
    items_to_process = [ 1, total_items.to_i ].max

    (1..items_to_process).each do |i|
      # Simulate work
      sleep([ delay_ms.to_i, 1 ].max / 1000.0)

      # Send 2025-spec compliant progress notification
      send_2025_progress_notification(
        progress_token: progress_token,
        current: i,
        total: items_to_process,
        item_name: "item_#{i}"
      )

      # Add to our output content
      output_content << "Processed item #{i} of #{items_to_process}"
    end

    # Render final result with all processed items
    render text: output_content.join("\n")
  end

  private

  def extract_progress_token
    # Try to get token from request metadata if available
    if execution_context&.request&.dig("params", "_meta", "progressToken")
      return execution_context.request.dig("params", "_meta", "progressToken")
    end

    # For testing, generate a consistent test token based on the execution time
    @extract_progress_token ||= "test_progress_token_#{Time.now.to_i}"
  end

  def send_2025_progress_notification(progress_token:, current:, total:, item_name:)
    message = "Processing #{item_name} (#{current}/#{total})"

    # Create and send the notification directly using the session
    if execution_context.present? && execution_context.session.present?
      execution_context.session.send_progress_notification(
        progressToken: progress_token,
        progress: current,
        total: total,
        message: message
      )
    else
      Rails.logger.warn "No session available for progress notifications"
    end

    # Log the progress for debugging
    Rails.logger.debug "Progress notification: #{progress_token} - #{current}/#{total} - #{message}"
  end
end
