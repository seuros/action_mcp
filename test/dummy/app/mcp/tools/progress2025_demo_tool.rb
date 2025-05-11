# test/dummy/app/mcp/tools/progress_2025_demo_tool.rb
class Progress2025DemoTool < ApplicationMCPTool
  tool_name "progress_2025_demo"
  description "Demo tool showing 2025-03-26 progress notifications"

  property :total_items, type: "integer", description: "Total items to process", default: 5
  property :delay_ms, type: "integer", description: "Delay between items in milliseconds", default: 10

  def perform
    # Extract progressToken from request metadata if available
    progress_token = extract_progress_token

    (1..total_items).each do |i|
      # Simulate work
      sleep(delay_ms / 1000.0)

      # Send 2025-spec compliant progress notification
      send_2025_progress_notification(
        progress_token: progress_token,
        current: i,
        total: total_items,
        item_name: "item_#{i}"
      )

      render text: "Processed item #{i} of #{total_items}"
    end
  end

  private

  def extract_progress_token
    # For testing, generate a test token
    "test_progress_token_#{Time.now.to_i}"
  end

  def send_2025_progress_notification(progress_token:, current:, total:, item_name:)
    message = "Processing #{item_name} (#{current}/#{total})"

    # Use the session from execution context
    if session && session.respond_to?(:messages)
      # Create and send the notification through the session
      notification = ActionMCP::JSON_RPC::Notification.new(
        method: "notifications/progress",
        params: {
          progressToken: progress_token,
          progress: current,
          total: total,
          message: message
        }
      )

      # Write the notification to the session
      session.write(notification)
    end
  end
end