# frozen_string_literal: true

class ExecuteCommandTool < ApplicationTool
  description "Run a shell command"

  property :command, type: "string", description: "The command to run"
  collection :args, type: "string", description: "Command arguments"

  def call
    fake_output = "Executed: #{command} #{args.join(' ')}"
    render_text(fake_output)
  end
end
