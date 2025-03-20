# In log_subscriber.rb
module ActionMCP
  class LogSubscriber < ActiveSupport::LogSubscriber
    def tool_call(event)
      # Try both debug and info to ensure output regardless of logger level
      debug "Tool: #{event.payload[:tool_name]} (#{event.duration.round(2)}ms)"
      info "Tool: #{event.payload[:tool_name]} (#{event.duration.round(2)}ms)"

      # Track total tool time for summary
      Thread.current[:tool_runtime] ||= 0
      Thread.current[:tool_runtime] += event.duration
    end

    def prompt_call(event)
      # Add debug output to confirm method is called
      puts "LogSubscriber#prompt_call called with: #{event.name}"

      # Try both debug and info to ensure output regardless of logger level
      debug "Prompt: #{event.payload[:prompt_name]} (#{event.duration.round(2)}ms)"
      info "Prompt: #{event.payload[:prompt_name]} (#{event.duration.round(2)}ms)"

      # Track total prompt time for summary
      Thread.current[:prompt_runtime] ||= 0
      Thread.current[:prompt_runtime] += event.duration
    end
    attach_to :action_mcp
  end
end
