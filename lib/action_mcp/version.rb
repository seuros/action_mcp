# frozen_string_literal: true

require_relative "gem_version"
module ActionMCP
  VERSION = "0.3.0"

  class << self
    alias version gem_version
  end
end
