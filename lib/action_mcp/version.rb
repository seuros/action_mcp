# frozen_string_literal: true

require_relative "gem_version"
module ActionMCP
  VERSION = "0.32.1"

  class << self
    alias version gem_version
  end
end
