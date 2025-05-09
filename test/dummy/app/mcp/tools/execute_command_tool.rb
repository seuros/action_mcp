# frozen_string_literal: true

class ExecuteCommandTool < ApplicationMCPTool
  description "Run a shell command"

  property :command, type: "string", description: "The command to run"
  collection :args, type: "string", description: "Command arguments"

  def perform
    fake_output = "Executed: #{command} #{args.join(' ')}"
    render text: fake_output
  end
end
