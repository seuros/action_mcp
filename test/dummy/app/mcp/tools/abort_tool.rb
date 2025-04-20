class AbortTool < ApplicationMCPTool
  description "Demonstrates throw(:abort) inside callbacks"
  property :value, type: "string"
  before_perform { throw :abort }
  def perform = render text: "should never appear"
end
