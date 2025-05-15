# frozen_string_literal: true

class ExplosiveTool < ApplicationMCPTool
  title "Explosive Tool"
  description "always explodes"
  read_only
  idempotent
  def perform = raise("kaboom")
end
