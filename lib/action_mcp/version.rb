# frozen_string_literal: true

require_relative "gem_version"
module ActionMCP
  VERSION = "0.50.13"

  class << self
    alias version gem_version
  end
end
