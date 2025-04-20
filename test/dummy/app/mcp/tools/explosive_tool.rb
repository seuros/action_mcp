# frozen_string_literal: true

class ExplosiveTool < ApplicationMCPTool
  description "always explodes"
  def perform = raise("kaboom")
end
