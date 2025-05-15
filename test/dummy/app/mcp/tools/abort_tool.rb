# frozen_string_literal: true

class AbortTool < ApplicationMCPTool
  title "Abort Tool"
  description "Demonstrates throw(:abort) inside callbacks"
  read_only
  idempotent
  property :value, type: "string"
  before_perform { throw :abort }
  def perform = render text: "should never appear"
end
