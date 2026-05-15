# frozen_string_literal: true

class RequiredTaskDemoTool < ApplicationMCPTool
  tool_name "required_task_demo"
  description "Test tool that requires task-augmented execution"

  task_support :required

  def perform
    render(text: "done")
  end
end
