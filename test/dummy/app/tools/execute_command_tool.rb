# frozen_string_literal: true

class ExecuteCommandTool < ApplicationTool
  tool_name "execute_command"
  description "Run a shell command"

  property :command, type: "string", description: "The command to run"
  collection :args, type: "string", description: "Command arguments"
end
