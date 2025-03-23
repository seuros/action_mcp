# frozen_string_literal: true

module ActionMCP
  class LogSubscriber < ActiveSupport::LogSubscriber
    def self.reset_runtime
      # Get the combined runtime from both tool and prompt operations
      tool_rt = Thread.current[:mcp_tool_runtime] || 0
      prompt_rt = Thread.current[:mcp_prompt_runtime] || 0
      total_rt = tool_rt + prompt_rt

      # Reset both counters
      Thread.current[:mcp_tool_runtime] = 0
      Thread.current[:mcp_prompt_runtime] = 0

      # Return the total runtime
      total_rt
    end

    def tool_call(event)
      Thread.current[:mcp_tool_runtime] ||= 0
      Thread.current[:mcp_tool_runtime] += event.duration
    end

    def prompt_call(event)
      Thread.current[:mcp_prompt_runtime] ||= 0
      Thread.current[:mcp_prompt_runtime] += event.duration
    end

    attach_to :action_mcp
  end
end
