# frozen_string_literal: true

class ThreadReplyTool < ApplicationMCPTool
  tool_name "thread_reply"
  description "Replies in a message thread; clients may call the thread root_id"

  property :thread_id, type: "string", required: true
  alias_property :root_id, :thread_id
  property :position, type: "number", description: "Position of the reply in the thread"
  alias_property :seq, :position
  additional_properties true

  def perform
    render text: thread_id
  end
end
